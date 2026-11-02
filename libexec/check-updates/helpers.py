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


def sortie(libelle, commande):
    print(f"{libelle}\t{commande}")


def remarque(texte):
    print(f"#\t{texte}")


def telecharger(url, timeout=10):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return r.read()


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
            return nom, extraire(json.loads(telecharger(url.format(nom))))
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
            sortie(f"{f['name']} {f['installed_versions'][-1]} → {f['current_version']}", f"brew upgrade {f['name']}")
    for c in d["casks"]:
        installee = c["installed_versions"]
        installee = installee[-1] if isinstance(installee, list) else installee
        sortie(f"{c['name']} {installee} → {c['current_version']} (cask)", f"brew upgrade --cask {c['name']}")


def npm():
    d = lire_json(sys.stdin.read(), {})
    if not isinstance(d, dict) or "error" in d:
        raise FormatInattendu("npm outdated --json: " + json.dumps(d)[:300])
    prefixe = os.environ.get("CU_PREFIX", "")
    for nom, p in d.items():
        if p.get("latest") and p.get("current") != p["latest"]:
            sortie(f"{nom} {p.get('current')} → {p['latest']}", f"{prefixe}npm install -g {nom}@latest")


def pnpm():
    d = lire_json(sys.stdin.read(), {})
    paquets = d.items() if isinstance(d, dict) else ((p["packageName"], p) for p in d)
    for nom, p in paquets:
        if p.get("latest") and p.get("current") != p["latest"]:
            sortie(f"{nom} {p.get('current')} → {p['latest']}", f"pnpm add -g {nom}@latest")


def composer():
    d = lire_json(sys.stdin.read(), {"installed": []})
    if d == []:  # rien en retard
        return
    if "installed" not in d:
        raise FormatInattendu("composer outdated --format=json: key 'installed' missing")
    for p in d["installed"]:
        sortie(f"{p['name']} {p['version']} → {p['latest']}", f"composer global update {p['name']} -W")


def mise():
    d = lire_json(sys.stdin.read(), {})
    outils = d.values() if isinstance(d, dict) else d
    for o in outils:
        if o.get("latest") and o.get("current") != o["latest"]:
            sortie(f"{o['name']} {o.get('current')} → {o['latest']}", f"mise upgrade {o['name']}")


PYPI = "https://pypi.org/pypi/{}/json"


def pipx():
    d = lire_json(sys.stdin.read(), {"venvs": {}})
    installes = {}
    for venv in d["venvs"].values():
        paquet = venv["metadata"]["main_package"]
        installes[paquet["package"]] = paquet["package_version"]
    dernieres = dernieres_versions(installes, PYPI, lambda j: j["info"]["version"])
    for nom, version in sorted(installes.items()):
        if dernieres.get(nom) and plus_recent(dernieres[nom], version):
            sortie(f"{nom} {version} → {dernieres[nom]}", f"pipx upgrade {nom}")


def uv():
    installes = {}
    for ligne in sys.stdin.read().splitlines():
        m = re.match(r"^(\S+) v(\S+)", ligne)
        if m:
            installes[m.group(1)] = m.group(2)
    dernieres = dernieres_versions(installes, PYPI, lambda j: j["info"]["version"])
    for nom, version in sorted(installes.items()):
        if dernieres.get(nom) and plus_recent(dernieres[nom], version):
            sortie(f"{nom} {version} → {dernieres[nom]}", f"uv tool upgrade {nom}")


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
        if dernieres.get(nom) and plus_recent(dernieres[nom], version):
            sortie(f"{nom} {version} → {dernieres[nom]}", f"cargo install {nom}")


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
        brut = telecharger(CASK_URL, 30)
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
        courte, build = lire_appcast(telecharger(info["SUFeedURL"], 8))
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
    if nouvelle:
        dispo = re.sub(r"^[^0-9]*", "", dispo)
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
        dispo = str(cask["version"])
        if plus_recent(dispo, installee):
            if cask.get("auto_updates"):
                action, commande = os.environ.get("CU_OPEN_APP", "open"), f"open -a {shlex.quote(chemin)}"
            else:
                action, commande = os.environ.get("CU_OPEN_SITE", "website"), f"open {shlex.quote(cask['homepage'])}"
            sortie(f"{nom[:-4]} {installee} → {dispo.split(',')[0]} ({action})", commande)

    with ThreadPoolExecutor(8) as pool:
        for resultat in pool.map(via_sparkle, pour_sparkle):
            if resultat:
                sortie(*resultat)


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

    catalogue = catalogue_casks()
    verifier_catalogue(catalogue)
    index = index_apps(catalogue)
    for app in ("Firefox.app", "iTerm.app", "Visual Studio Code.app"):
        if app not in index:
            raise FormatInattendu(f"cask catalog: {app} not found, app artifacts format may have changed")
    print("ok")


COMMANDES = {f.__name__: f for f in (brew, npm, pnpm, composer, mise, pipx, uv, cargo, apps, selftest)}

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
