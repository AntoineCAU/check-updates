"""Analyseurs de check-updates.

Chaque commande lit la sortie d'un gestionnaire de paquets (ou interroge un registre)
et écrit « libellé<TAB>commande » par mise à jour, « #<TAB>texte » pour une remarque.
Dès que le format reçu n'est pas celui attendu, elle échoue (code 3) au lieu de ne
rien afficher : check-updates signale alors la source en erreur plutôt que « à jour ».

Python 3.9 (celui des Command Line Tools d'Apple), bibliothèque standard uniquement.
"""
import json
import os
import plistlib
import re
import shlex
import socket
import subprocess
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor

UA = {"User-Agent": "check-updates (https://github.com/AntoineCAU/check-updates)"}
CACHE = os.environ.get("CU_CACHE", os.path.expanduser("~/Library/Caches/check-updates"))
CASK_URL = "https://formulae.brew.sh/api/cask.json"
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
DOSSIERS_APPS = ("/Applications", "/Applications/Utilities", os.path.expanduser("~/Applications"))
CASKROOMS = ("/opt/homebrew/Caskroom", "/usr/local/Caskroom")


class FormatInattendu(Exception):
    pass


# Les libellés et les commandes viennent en partie d'Internet (flux Sparkle, registres) :
# une tabulation ou un retour à la ligne permettrait de fabriquer une fausse ligne avec sa
# propre commande. On les retire de tout ce qui est écrit, et les versions distantes doivent
# ressembler à une version.
CONTROLE = re.compile(r"[\x00-\x1f\x7f]+")
VERSION_SURE = re.compile(r"^[0-9A-Za-z][0-9A-Za-z.+~_-]{0,63}$")
MAX_FLUX = 5 * 1024 * 1024  # flux Sparkle
MAX_REGISTRE = 50 * 1024 * 1024  # PyPI et crates.io listent toutes les versions publiées
MAX_CATALOGUE = 100 * 1024 * 1024


def propre(texte):
    return CONTROLE.sub(" ", str(texte)).strip()


def version_sure(version):
    return bool(VERSION_SURE.match(str(version)))


def q(nom):
    return shlex.quote(str(nom))


def sortie(libelle, commande):
    print(f"{propre(libelle)}\t{propre(commande)}")


def remarque(texte):
    print(f"#\t{texte}")


def telecharger(url, timeout=10, maximum=MAX_FLUX, corps=None, entetes=None):
    if not str(url).startswith(("https://", "http://")):
        raise OSError(f"unsupported URL: {url}")
    requete = urllib.request.Request(url, data=corps, headers={**UA, **(entetes or {})})
    with urllib.request.urlopen(requete, timeout=timeout) as r:
        donnees = r.read(maximum + 1)
    if len(donnees) > maximum:
        raise OSError(f"response too large: {url}")
    return donnees


def lire_json(texte, vide):
    """JSON en ignorant le bruit éventuel avant (avertissements PHP, etc.)."""
    texte = texte.strip()
    if not texte:
        return vide
    debuts = [i for i in (texte.find("{"), texte.find("[")) if i >= 0]
    if not debuts:
        raise FormatInattendu("JSON expected, got: " + " / ".join(texte.splitlines()[:2])[:300])
    return json.loads(texte[min(debuts):])


def morceaux(version):
    """« 4.97.0,244584 » → [4, 97, 0] (la partie après la virgule est un numéro de build)."""
    return [int(x) for x in re.findall(r"\d+", str(version).split(",")[0])]


def plus_recent(dispo, installee):
    a, b = morceaux(dispo), morceaux(installee)
    # Schémas différents (date contre semver, etc.) : on ne conclut pas plutôt que d'inventer une mise à jour
    if not a or not b or len(str(a[0])) != len(str(b[0])):
        return False
    n = max(len(a), len(b))
    return a + [0] * (n - len(a)) > b + [0] * (n - len(b))


def dernieres_versions(noms, url, extraire):
    """Interroge un registre en parallèle ; ignore les paquets introuvables."""
    def une(nom):
        try:
            return nom, extraire(json.loads(telecharger(url.format(nom), 15, MAX_REGISTRE)))
        except Exception:
            return nom, None
    with ThreadPoolExecutor(8) as pool:
        return dict(pool.map(une, noms))


# --- Gestionnaires de paquets -------------------------------------------------

def brew():
    d = lire_json(sys.stdin.read(), {})
    if not isinstance(d, dict) or "formulae" not in d or "casks" not in d:
        raise FormatInattendu("brew outdated --json=v2: keys 'formulae'/'casks' missing")
    for f in d["formulae"]:
        if not f.get("pinned"):
            sortie(f"{f['name']} {f['installed_versions'][-1]} → {f['current_version']}", f"brew upgrade {q(f['name'])}")
    for c in d["casks"]:
        installee = c["installed_versions"]
        installee = installee[-1] if isinstance(installee, list) else installee
        sortie(f"{c['name']} {installee} → {c['current_version']} (cask)", f"brew upgrade --cask {q(c['name'])}")


def npm():
    d = lire_json(sys.stdin.read(), {})
    if not isinstance(d, dict) or "error" in d:
        raise FormatInattendu("npm outdated --json: " + json.dumps(d)[:300])
    prefixe = os.environ.get("CU_PREFIX", "")
    for nom, p in d.items():
        if p.get("latest") and p.get("current") != p["latest"]:
            sortie(f"{nom} {p.get('current')} → {p['latest']}", f"{prefixe}npm install -g {q(nom + '@latest')}")


def pnpm():
    d = lire_json(sys.stdin.read(), {})
    paquets = d.items() if isinstance(d, dict) else ((p["packageName"], p) for p in d)
    for nom, p in paquets:
        if p.get("latest") and p.get("current") != p["latest"]:
            sortie(f"{nom} {p.get('current')} → {p['latest']}", f"pnpm add -g {q(nom + '@latest')}")


def composer():
    d = lire_json(sys.stdin.read(), {"installed": []})
    if d == []:  # rien en retard
        return
    if "installed" not in d:
        raise FormatInattendu("composer outdated --format=json: key 'installed' missing")
    for p in d["installed"]:
        sortie(f"{p['name']} {p['version']} → {p['latest']}", f"composer global update {q(p['name'])} -W")


def mise():
    d = lire_json(sys.stdin.read(), {})
    outils = d.values() if isinstance(d, dict) else d
    for o in outils:
        if o.get("latest") and o.get("current") != o["latest"]:
            sortie(f"{o['name']} {o.get('current')} → {o['latest']}", f"mise upgrade {q(o['name'])}")


PYPI = "https://pypi.org/pypi/{}/json"


def pipx():
    d = lire_json(sys.stdin.read(), {"venvs": {}})
    installes = {}
    for venv in d["venvs"].values():
        paquet = venv["metadata"]["main_package"]
        installes[paquet["package"]] = paquet["package_version"]
    dernieres = dernieres_versions(installes, PYPI, lambda j: j["info"]["version"])
    for nom, version in sorted(installes.items()):
        if version_sure(dernieres.get(nom) or "") and plus_recent(dernieres[nom], version):
            sortie(f"{nom} {version} → {dernieres[nom]}", f"pipx upgrade {q(nom)}")


def uv():
    installes = {}
    for ligne in sys.stdin.read().splitlines():
        m = re.match(r"^(\S+) v(\S+)", ligne)
        if m:
            installes[m.group(1)] = m.group(2)
    dernieres = dernieres_versions(installes, PYPI, lambda j: j["info"]["version"])
    for nom, version in sorted(installes.items()):
        if version_sure(dernieres.get(nom) or "") and plus_recent(dernieres[nom], version):
            sortie(f"{nom} {version} → {dernieres[nom]}", f"uv tool upgrade {q(nom)}")


def cargo():
    with open(os.path.expanduser("~/.cargo/.crates2.json")) as f:
        installs = json.load(f)["installs"]
    installes = {}
    for cle in installs:
        nom, version, source = cle.split(" ", 2)
        if "crates.io-index" in source:  # pas les installations depuis git ou un chemin local
            installes[nom] = version
    dernieres = dernieres_versions(installes, "https://crates.io/api/v1/crates/{}", lambda j: j["crate"]["max_stable_version"])
    for nom, version in sorted(installes.items()):
        if version_sure(dernieres.get(nom) or "") and plus_recent(dernieres[nom], version):
            sortie(f"{nom} {version} → {dernieres[nom]}", f"cargo install {q(nom)}")


def tlmgr():
    """« tlmgr --machine-readable update --list » : un paquet par ligne entre
    « end-of-header » et « end-of-updates », trop nombreux pour une ligne chacun."""
    annee, sudo = sys.argv[2], os.environ.get("CU_PREFIX", "")
    lignes = sys.stdin.read().replace("\r", "").splitlines()
    if "end-of-header" not in lignes or "end-of-updates" not in lignes:
        raise FormatInattendu("tlmgr: end-of-header/end-of-updates missing: " + " / ".join(lignes[:2])[:300])
    paquets = lignes[lignes.index("end-of-header") + 1:lignes.index("end-of-updates")]
    n = sum(1 for p in paquets if p.split("\t")[1:2] in (["u"], ["a"]))
    if n:
        sortie(f"TeX Live {annee} ({n} package{'s' if n > 1 else ''})", f"{sudo}tlmgr update --self --all")


# --- Outils qui se mettent à jour eux-mêmes -----------------------------------

def autonome(nom, installee, derniere, commande):
    if version_sure(derniere) and plus_recent(derniere, installee):
        sortie(f"{nom} {installee} → {derniere}", commande)


def bun():
    """Version installée en argument, comparée au paquet npm « bun » publié à chaque version."""
    chemin, installee = sys.argv[2], sys.stdin.read().strip()
    if not re.match(r"^\d+\.\d+", installee):
        raise FormatInattendu(f"bun --version: {installee[:100]}")
    derniere = json.loads(telecharger("https://registry.npmjs.org/bun/latest"))["version"]
    autonome("bun", installee, derniere, f"{q(chemin)} upgrade")


def deno():
    """« deno 2.1.4 (stable, release, aarch64-apple-darwin) » comparé à la dernière version."""
    chemin, texte = sys.argv[2], sys.stdin.read()
    m = re.match(r"^deno (\d\S*)", texte)
    if not m:
        raise FormatInattendu(f"deno --version: {texte[:100]}")
    derniere = telecharger("https://dl.deno.land/release-latest.txt").decode().strip().lstrip("v")
    autonome("deno", m.group(1), derniere, f"{q(chemin)} upgrade")


def gh():
    """« [   dash]: would have upgraded from v4.20.0 to v4.26.2 » ; une extension en script
    n'a qu'un numéro de commit à la place de la version."""
    for ligne in sys.stdin.read().splitlines():
        if not ligne.strip():
            continue
        m = re.match(r"^\[\s*(\S+)\]: (.*)$", ligne)
        if not m:
            raise FormatInattendu(f"gh extension upgrade --dry-run: {ligne[:200]}")
        nom, reste = m.groups()
        if reste in ("already up to date", "local extensions can not be upgraded", "pinned extensions can not be upgraded"):
            continue
        m = re.match(r"^would have upgraded from (\S+) to (\S+)$", reste)
        if not m:
            raise FormatInattendu(f"gh extension upgrade --dry-run: {ligne[:200]}")
        de, vers = m.groups()
        if not version_sure(vers):
            continue
        commande = f"gh extension upgrade {q(nom)}"
        if re.match(r"^[0-9a-f]{7,40}$", vers):
            sortie(f"gh-{nom} (commit {vers})", commande)
        else:
            sortie(f"gh-{nom} {de} → {vers}", commande)


MARKETPLACE = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"


def marketplace(ids, toutes):
    """Versions publiées des extensions, par identifiant en minuscules. Sans « toutes », seule
    la dernière de chaque plateforme, qui peut être une préversion."""
    criteres = [{"filterType": 7, "value": i} for i in ids] + [{"filterType": 8, "value": "Microsoft.VisualStudio.Code"}]
    flags = 0x1 | 0x10 if toutes else 0x200 | 0x10  # IncludeVersions ou IncludeLatestVersionOnly, + propriétés
    corps = json.dumps({"filters": [{"criteria": criteres, "pageSize": 1000}], "flags": flags}).encode()
    entetes = {"Accept": "application/json;api-version=3.0-preview.1", "Content-Type": "application/json"}
    d = json.loads(telecharger(MARKETPLACE, 30, MAX_REGISTRE, corps, entetes))
    return {f"{e['publisher']['publisherName']}.{e['extensionName']}".lower(): e["versions"] for e in d["results"][0]["extensions"]}


def compatible(moteur, code):
    m = re.match(r"^\s*[\^>=~]*\s*(\d+)\.(\d+)", moteur or "")
    return not m or [int(m.group(1)), int(m.group(2))] <= morceaux(code)[:2]


def version_stable(versions, code):
    """Plus récente version stable, pour ce Mac et cette version de VS Code."""
    plateforme = "darwin-arm64" if os.uname().machine == "arm64" else "darwin-x64"
    retenue = None
    for v in versions:
        proprietes = {p["key"]: p["value"] for p in v.get("properties", [])}
        if (proprietes.get("Microsoft.VisualStudio.Code.PreRelease") != "true"
                and v.get("targetPlatform") in (None, "universal", plateforme)
                and compatible(proprietes.get("Microsoft.VisualStudio.Code.Engine"), code)
                and (retenue is None or plus_recent(v["version"], retenue))):
            retenue = v["version"]
    return retenue


def vscode():
    """« publisher.name@1.2.3 » par ligne (code --list-extensions --show-versions)."""
    cli, code = os.environ["CU_CODE"], os.environ["CU_CODE_VERSION"]
    installees = {}
    for ligne in sys.stdin.read().splitlines():
        if ligne.strip():
            m = re.match(r"^([\w-]+\.[\w.-]+)@(\S+)$", ligne.strip())
            if not m:
                raise FormatInattendu(f"code --list-extensions --show-versions: {ligne[:200]}")
            installees[m.group(1)] = m.group(2)
    if not installees:
        return
    publiees = marketplace(installees, False)
    dernieres = {i: version_stable(v, code) for i, v in publiees.items()}
    # Dernière publiée = préversion ou VS Code trop ancien : toutes les versions, une par une
    manquantes = [i for i in installees if publiees.get(i.lower()) and not dernieres[i.lower()]]
    with ThreadPoolExecutor(8) as pool:
        for complet in pool.map(lambda i: marketplace([i], True), manquantes):
            dernieres.update({i: version_stable(v, code) for i, v in complet.items()})
    for ext, version in sorted(installees.items(), key=lambda e: e[0].lower()):
        derniere = dernieres.get(ext.lower())
        if derniere and version_sure(derniere) and plus_recent(derniere, version):
            sortie(f"{ext} {version} → {derniere}", f"{q(cli)} --install-extension {q(ext)} --force")


# --- Applications -------------------------------------------------------------

def catalogue_casks():
    """Catalogue public des casks Homebrew, mis en cache une fois par jour."""
    chemin = os.path.join(CACHE, "cask.json")
    try:
        if time.time() - os.path.getmtime(chemin) < 20 * 3600:
            with open(chemin) as f:
                return json.load(f)
    except (OSError, ValueError):
        pass
    try:
        brut = telecharger(CASK_URL, 30, MAX_CATALOGUE)
        d = json.loads(brut)
    except Exception as e:
        if not os.path.exists(chemin):
            raise
        print(f"cask catalog download failed ({e}), using cached copy", file=sys.stderr)
        with open(chemin) as f:
            return json.load(f)
    os.makedirs(CACHE, exist_ok=True)
    with open(chemin + ".tmp", "wb") as f:
        f.write(brut)
    os.replace(chemin + ".tmp", chemin)
    return d


def verifier_catalogue(catalogue):
    if not isinstance(catalogue, list) or len(catalogue) < 1000:
        raise FormatInattendu("cask catalog: list of casks expected")
    for cle in ("token", "version", "artifacts", "homepage"):
        if cle not in catalogue[0]:
            raise FormatInattendu(f"cask catalog: key '{cle}' missing")


def noms_apps(cask):
    """Noms des .app installées par un cask (« app 'A.app', target: 'B.app' » → B.app)."""
    noms = []
    for artefact in cask.get("artifacts") or []:
        if isinstance(artefact, dict) and isinstance(artefact.get("app"), list):
            cibles = [x["target"] for x in artefact["app"] if isinstance(x, dict) and "target" in x]
            noms += [os.path.basename(n) for n in (cibles or [x for x in artefact["app"] if isinstance(x, str)])]
    return noms


def simplifier(nom):
    return re.sub(r"[^a-z0-9]", "", nom.lower())


def identifiants(cask):
    """Identifiants d'app que le cask déclare (quit/signal de uninstall et zap)."""
    ids = set()
    for artefact in cask.get("artifacts") or []:
        for directives in (artefact.get("uninstall"), artefact.get("zap")) if isinstance(artefact, dict) else ():
            for d in directives or []:
                if isinstance(d, dict):
                    quit_ = d.get("quit") or []
                    ids.update([quit_] if isinstance(quit_, str) else quit_)
    return ids


def index_apps(catalogue):
    index = {}
    for cask in catalogue:
        for nom in noms_apps(cask):
            deja = index.get(nom)
            # Préférer le cask principal (« firefox ») aux variantes (« firefox@beta »)
            if deja is None or ("@" in deja["token"] and "@" not in cask["token"]):
                index[nom] = cask
    return index


def apps_installees():
    for dossier in DOSSIERS_APPS:
        try:
            noms = sorted(os.listdir(dossier))
        except OSError:
            continue
        for nom in noms:
            chemin = os.path.join(dossier, nom)
            if not nom.endswith(".app") or os.path.exists(os.path.join(chemin, "Contents/_MASReceipt")):
                continue  # les apps de l'App Store sont vérifiées par mas
            try:
                with open(os.path.join(chemin, "Contents/Info.plist"), "rb") as f:
                    info = plistlib.load(f)
            except Exception:
                continue
            if not str(info.get("CFBundleIdentifier", "")).startswith("com.apple."):
                yield nom, chemin, info


def lire_appcast(donnees):
    """Dernière version stable d'un flux Sparkle : (version courte, numéro de build)."""
    # Le Python d'Apple embarque un expat sans protection contre l'expansion d'entités
    # (« billion laughs ») : un flux Sparkle n'a jamais de DTD, on refuse ceux qui en ont
    if b"<!DOCTYPE" in donnees or b"<!ENTITY" in donnees:
        raise FormatInattendu("appcast with a DTD refused")
    meilleure = None
    for item in ET.fromstring(donnees).iter("item"):
        if item.find(SPARKLE + "channel") is not None:
            continue  # bêta, nightly…
        enc = item.find("enclosure")
        attr = enc.attrib if enc is not None else {}
        courte = item.findtext(SPARKLE + "shortVersionString") or attr.get(SPARKLE + "shortVersionString") or ""
        build = item.findtext(SPARKLE + "version") or attr.get(SPARKLE + "version") or ""
        cle = morceaux(courte or build)
        if cle and (meilleure is None or cle > meilleure[0]):
            meilleure = (cle, courte, build)
    return meilleure[1:] if meilleure else ("", "")


def via_sparkle(args):
    nom, chemin, info = args
    try:
        courte, build = lire_appcast(telecharger(str(info["SUFeedURL"]), 8))
    except Exception:
        return None  # flux injoignable ou illisible : on n'invente rien pour cette app
    installee_courte = str(info.get("CFBundleShortVersionString", ""))
    installee_build = str(info.get("CFBundleVersion", ""))
    if courte and installee_courte:
        nouvelle, installee, dispo = plus_recent(courte, installee_courte), installee_courte, courte
    elif build and installee_build:
        nouvelle, installee, dispo = plus_recent(build, installee_build), installee_build, build
    else:
        return None
    dispo = re.sub(r"^[^0-9]*", "", dispo)
    if nouvelle and version_sure(dispo):
        return f"{nom[:-4]} {installee} → {dispo} ({os.environ.get('CU_OPEN_APP', 'open')})", f"open -a {shlex.quote(chemin)}"
    return None


def apps():
    catalogue = catalogue_casks()
    verifier_catalogue(catalogue)
    index = index_apps(catalogue)
    par_token = {c["token"]: c for c in catalogue}

    # Les apps installées par brew sont déjà couvertes par « brew outdated » : on les reconnaît
    # à leur nom, à celui du cask (installations .pkg) ou aux identifiants qu'il déclare
    geres_par_brew = set()
    for caskroom in CASKROOMS:
        try:
            tokens = os.listdir(caskroom)
        except OSError:
            continue
        for token in tokens:
            cask = par_token.get(token, {})
            geres_par_brew.update(noms_apps(cask))
            geres_par_brew.add(simplifier(token.split("@")[0]))
            geres_par_brew.update(identifiants(cask))

    pour_sparkle = []
    for nom, chemin, info in apps_installees():
        if {nom, simplifier(nom[:-4]), info.get("CFBundleIdentifier")} & geres_par_brew:
            continue
        cask = index.get(nom)
        if cask is None:
            if info.get("SUFeedURL"):
                pour_sparkle.append((nom, chemin, info))
            continue
        installee = str(info.get("CFBundleShortVersionString", ""))
        dispo = str(cask["version"]).split(",")[0]
        if not version_sure(dispo):
            continue
        if plus_recent(dispo, installee):
            if cask.get("auto_updates"):
                action, commande = os.environ.get("CU_OPEN_APP", "open"), f"open -a {shlex.quote(chemin)}"
            elif str(cask.get("homepage", "")).startswith(("https://", "http://")):
                action, commande = os.environ.get("CU_OPEN_SITE", "website"), f"open {q(cask['homepage'])}"
            else:
                continue
            sortie(f"{nom[:-4]} {installee} → {dispo} ({action})", commande)

    with ThreadPoolExecutor(8) as pool:
        for resultat in pool.map(via_sparkle, pour_sparkle):
            if resultat:
                sortie(*resultat)


# --- Masquage avant envoi à une IA -------------------------------------------

SECRETS = [
    # Clé privée entière
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.S), "[redacted private key]"),
    # Identifiants dans une URL : https://user:pass@hôte, https://jeton@hôte
    (re.compile(r"(\b[a-z][a-z0-9+.-]*://)[^/\s:@]+:[^/\s@]+@", re.I), r"\1[redacted]@"),
    (re.compile(r"(\bhttps?://)[^/\s:@]{16,}@", re.I), r"\1[redacted]@"),
    # En-têtes et schémas d'authentification
    (re.compile(r"\b(bearer|basic|token)(\s+)[A-Za-z0-9._~+/=-]{8,}", re.I), r"\1\2[redacted]"),
    # Formats de jetons connus
    (re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})"), "[redacted]"),
    (re.compile(r"\bnpm_[A-Za-z0-9]{20,}"), "[redacted]"),
    (re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"), "[redacted]"),  # OpenAI, Anthropic (sk-ant-…)
    (re.compile(r"\b(sk|rk)_(live|test)_[A-Za-z0-9]{10,}"), "[redacted]"),  # Stripe
    (re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b"), "[redacted]"),  # AWS
    (re.compile(r"\bxox[abposr]-[A-Za-z0-9-]{10,}"), "[redacted]"),  # Slack
    (re.compile(r"\bAIza[0-9A-Za-z_-]{35}"), "[redacted]"),  # Google
    (re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"), "[redacted]"),  # JWT
    # clé=valeur / clé: valeur dont le nom évoque un secret
    (re.compile(r"(\b[A-Za-z0-9_.-]*(?:password|passwd|pwd|secret|token|api[_-]?key|access[_-]?key|auth)[A-Za-z0-9_.-]*\s*[=:]\s*)(?!(?:bearer|basic|token)\s)(\"[^\"]*\"|'[^']*'|\S+)", re.I), r"\1[redacted]"),
]


def identite():
    """Dossier personnel, nom d'utilisateur et noms de la machine, à masquer."""
    noms_machine = {socket.gethostname(), socket.gethostname().split(".")[0]}
    for cle in ("ComputerName", "LocalHostName"):
        try:
            noms_machine.add(subprocess.run(["scutil", "--get", cle], capture_output=True, text=True, timeout=5).stdout.strip())
        except Exception:
            pass
    return os.path.expanduser("~"), os.environ.get("USER") or os.path.basename(os.path.expanduser("~")), {n for n in noms_machine if len(n) > 2}


def masquer(texte, dossier, utilisateur, machines):
    for motif, remplacement in SECRETS:
        texte = motif.sub(remplacement, texte)
    texte = texte.replace(dossier, "~")
    for machine in sorted(machines, key=len, reverse=True):
        texte = re.sub(re.escape(machine), "[host]", texte, flags=re.I)
    if len(utilisateur) > 2:
        texte = re.sub(r"\b" + re.escape(utilisateur) + r"\b", "[user]", texte)
    return texte


def redact():
    sys.stdout.write(masquer(sys.stdin.read(), *identite()))


# --- Autotest (check-updates doctor, CI) --------------------------------------

APPCAST_EXEMPLE = b"""<?xml version="1.0"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0"><channel>
<item><sparkle:version>120</sparkle:version><sparkle:shortVersionString>1.2.0</sparkle:shortVersionString>
<enclosure url="https://example.com/a.zip"/></item>
<item><sparkle:channel>beta</sparkle:channel><enclosure url="https://example.com/b.zip" sparkle:version="140" sparkle:shortVersionString="1.4.0b1"/></item>
<item><enclosure url="https://example.com/c.zip" sparkle:version="130" sparkle:shortVersionString="1.3.0"/></item>
</channel></rss>"""


def selftest():
    assert plus_recent("4.97.0,244584", "4.83.0")
    assert plus_recent("1.10", "1.9")
    assert not plus_recent("3.7.4", "3.7.4")
    assert not plus_recent("1.2", "1.2.0")
    assert not plus_recent("2024.05", "5.1"), "different version schemes must not be compared"
    assert not plus_recent("latest", "1.0")
    assert lire_appcast(APPCAST_EXEMPLE) == ("1.3.0", "130"), lire_appcast(APPCAST_EXEMPLE)
    assert propre("a\tb\nc") == "a b c"
    assert version_sure("4.97.0") and version_sure("1.0b3") and version_sure("v2.1+build.5")
    try:
        lire_appcast(b'<?xml version="1.0"?><!DOCTYPE r [<!ENTITY a "aaaa">]><rss>&a;</rss>')
        raise AssertionError("appcast with a DTD must be refused")
    except FormatInattendu:
        pass
    ident = ("/Users/jdoe", "jdoe", {"Janes-MacBook-Pro", "Janes-MacBook-Pro.local", "Jane's MacBook Pro"})
    exemples = {
        "fatal: https://jdoe:hunter2@github.com/x.git": "fatal: https://[redacted]@github.com/x.git",
        "remote: https://ghp_abcdefghijklmnopqrstuvwxyz0123@github.com": "remote: https://[redacted]@github.com",
        "Authorization: Bearer abc.def-ghi_jkl": "Authorization: Bearer [redacted]",
        "//registry.npmjs.org/:_authToken=npm_abcdefghijklmnopqrstuvwxyz": "//registry.npmjs.org/:_authToken=[redacted]",
        "OPENAI_API_KEY=sk-proj-abcdefghijklmnopqrstuvwxyz": "OPENAI_API_KEY=[redacted]",
        "key AKIAABCDEFGHIJKLMNOP used": "key [redacted] used",
        'password: "s3cr3t" ok': "password: [redacted] ok",
        "/Users/jdoe/.nvm/versions/node/v24/bin/npm": "~/.nvm/versions/node/v24/bin/npm",
        "jdoe@Janes-MacBook-Pro.local:~ $": "[user]@[host]:~ $",
        "Error: npm ERR! code E404 404 Not Found": "Error: npm ERR! code E404 404 Not Found",
    }
    for avant, apres in exemples.items():
        obtenu = masquer(avant, *ident)
        assert obtenu == apres, f"redact: {avant!r} → {obtenu!r}, expected {apres!r}"
    assert not version_sure("9.9\nEvil\tcurl x | sh") and not version_sure("1.0; rm -rf ~") and not version_sure("")

    catalogue = catalogue_casks()
    verifier_catalogue(catalogue)
    index = index_apps(catalogue)
    for app in ("Firefox.app", "iTerm.app", "Visual Studio Code.app"):
        if app not in index:
            raise FormatInattendu(f"cask catalog: {app} not found, app artifacts format may have changed")
    print("ok")


COMMANDES = {f.__name__: f for f in (brew, npm, pnpm, composer, mise, pipx, uv, cargo, tlmgr, bun, deno, gh, vscode,
                                      apps, redact, selftest)}

if __name__ == "__main__":
    nom = sys.argv[1] if len(sys.argv) > 1 else ""
    if nom not in COMMANDES:
        sys.exit(f"usage: helpers.py {'|'.join(COMMANDES)}")
    try:
        COMMANDES[nom]()
    except FormatInattendu as e:
        sys.exit(print(f"{nom}: unexpected format — {e}", file=sys.stderr) or 3)
    except (KeyError, TypeError, ValueError, AttributeError, IndexError, AssertionError, ET.ParseError) as e:
        sys.exit(print(f"{nom}: unexpected format — {type(e).__name__}: {e}", file=sys.stderr) or 3)
    except OSError as e:
        sys.exit(print(f"{nom}: network or file error — {e}", file=sys.stderr) or 4)
