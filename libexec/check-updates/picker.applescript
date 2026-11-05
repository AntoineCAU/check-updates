-- Liste des mises à jour, dans une fenêtre dessinée ici (NSPanel) plutôt qu'une alerte :
-- NSAlert réserve toujours la place d'une icône. Trois groupes :
--   automatiques : une case à cocher, installées après « Update » (pré-cochée, sauf version majeure) ;
--   dépendances : pareil, mais repliées en une ligne « tout mettre à jour » avec un bouton
--     « Show » qui redessine la fenêtre en les détaillant ;
--   à faire soi-même : un bouton « Open » qui ouvre tout de suite les Réglages, l'app ou le site.
-- Chaque ligne a aussi un bouton « Ignore » (ignorer cette version), et sa description en
-- petit dessous quand la source la connaît.
-- Arguments : titre, texte, boutons Update, Later, Done (s'il n'y a rien à cocher), Open,
-- libellé « ouvert », Ignore, libellé « ignoré », titre et explication de chaque groupe
-- (automatique, manuel, dépendances), libellé de la case du groupe replié (« %d » = nombre),
-- bouton Show, puis une ligne par mise à jour :
--   « A|B|M <tab> nom <tab> détail <tab> étiquette <tab> commande <tab> description <tab> dépendance »
--   (A cochée, B non cochée, M à faire soi-même avec la commande du bouton Open ;
--   dépendance = 1 pour le groupe des dépendances ; les derniers champs peuvent manquer)
-- Affiche une ligne par décision : « i N » pour chaque ligne ignorée, et si on valide,
-- « u N » pour chaque mise à jour cochée (N = numéro de la ligne, à partir de 1).
use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property largeur : 700
property marge : 20
property colonneDetail : 220
property largeurBouton : 70
property largeurEtiquette : 64
property hauteurLigne : 26
property hauteurInfo : 14 -- ligne de description sous la mise à jour
property hauteurTitreGroupe : 30
property ecartGroupes : 10
property hauteurMax : 440 -- au-delà, la liste défile
property premiereLigne : 18 -- index du premier argument « ligne »

property commandes : {} -- commande du bouton Open de chaque ligne
property casesParLigne : {} -- case à cocher de chaque ligne (missing value sinon)
property openParLigne : {} -- bouton Open de chaque ligne (missing value sinon)
property ignoreParLigne : {} -- bouton Ignore de chaque ligne (missing value sinon)
property etats : {} -- état choisi de chaque case, gardé quand la fenêtre est redessinée
property ignorees : {}
property caseGroupe : missing value -- case du groupe des dépendances replié
property deplie : false
property libelleOuvert : ""
property libelleIgnore : ""
property reponsesTest : {} -- tests : boutons « cliqués » d'avance (CU_PICKER_TEST=2,1 → Show puis Update)

on run argv
	set app_ to current application's NSApplication's sharedApplication()
	app_'s setActivationPolicy:1 -- accessory : osascript a le droit d'afficher une fenêtre, sans icône dans le Dock
	app_'s activateIgnoringOtherApps:true

	set automatiques to {}
	set dependances to {}
	set manuelles to {}
	set AppleScript's text item delimiters to tab
	repeat with i from premiereLigne to count of argv
		set champs to text items of (item i of argv)
		set ligne to {indice:(i - premiereLigne + 1), sorte:(item 1 of champs), nom:(item 2 of champs), detail:"", etiquette:"", commande:"", info:""}
		if (count of champs) > 2 then set detail of ligne to item 3 of champs
		if (count of champs) > 3 then set etiquette of ligne to item 4 of champs
		if (count of champs) > 4 then set commande of ligne to item 5 of champs
		if (count of champs) > 5 then set info of ligne to item 6 of champs
		if sorte of ligne is "M" then
			set end of manuelles to ligne
		else if (count of champs) > 6 and item 7 of champs is "1" then
			set end of dependances to ligne
		else
			set end of automatiques to ligne
		end if
		set end of commandes to commande of ligne
		set end of casesParLigne to missing value
		set end of openParLigne to missing value
		set end of ignoreParLigne to missing value
		set end of etats to missing value
	end repeat
	set AppleScript's text item delimiters to ""
	set libelleOuvert to item 7 of argv
	set libelleIgnore to item 9 of argv
	set test to system attribute "CU_PICKER_TEST"
	if test is not "" then
		set AppleScript's text item delimiters to ","
		repeat with r in text items of test
			set end of reponsesTest to (r as integer)
		end repeat
		set AppleScript's text item delimiters to ""
	end if

	-- Un seul groupe de dépendances court : inutile de le replier
	set deplie to (count of dependances) < 3
	repeat
		set reponse to my afficher(argv, automatiques, dependances, manuelles)
		if reponse is not 2 then exit repeat
		my memoriserEtats(dependances)
		set deplie to true
	end repeat

	set sortie to {}
	repeat with k in ignorees
		set end of sortie to "i " & k
	end repeat
	if reponse is 1 then -- 1 = Update
		repeat with k from 1 to count of casesParLigne
			set c to item k of casesParLigne
			if c is not missing value then
				if ((c's state()) as integer) is 1 and (c's isEnabled()) as boolean then set end of sortie to "u " & k
			end if
		end repeat
		if not deplie and caseGroupe is not missing value then
			if ((caseGroupe's state()) as integer) is 1 then
				repeat with l in dependances
					if sorte of l is "A" and ignorees does not contain (indice of l) then set end of sortie to "u " & (indice of l)
				end repeat
			end if
		end if
	end if
	set AppleScript's text item delimiters to linefeed
	return sortie as text
end run

-- Dessine la fenêtre et attend un bouton : 1 Update, 0 Later/Done, 2 Show (redessiner dépliée)
on afficher(argv, automatiques, dependances, manuelles)
	repeat with k from 1 to count of casesParLigne
		set item k of casesParLigne to missing value
		set item k of openParLigne to missing value
		set item k of ignoreParLigne to missing value
	end repeat
	set caseGroupe to missing value

	-- Colonnes de droite à gauche : Open, Ignore, étiquette, puis le détail
	set largeurListe to largeur - 2 * marge
	set xOpen to largeurListe - largeurBouton
	set xIgnore to xOpen - 6 - largeurBouton
	set xEtiquette to xIgnore - 8 - largeurEtiquette
	set largeurDetail to xEtiquette - 8 - colonneDetail
	set colonnes to {largeurDetail:largeurDetail, xEtiquette:xEtiquette, xIgnore:xIgnore, xOpen:xOpen}

	set groupes to 0
	set hauteurListe to 0
	if automatiques is not {} then set hauteurListe to hauteurListe + hauteurTitreGroupe + (my hauteurLignes(automatiques))
	if dependances is not {} then
		if deplie then
			set hauteurListe to hauteurListe + hauteurTitreGroupe + (my hauteurLignes(dependances))
		else
			set hauteurListe to hauteurListe + hauteurTitreGroupe + hauteurLigne
		end if
	end if
	if manuelles is not {} then set hauteurListe to hauteurListe + hauteurTitreGroupe + (my hauteurLignes(manuelles))
	repeat with g in {automatiques, dependances, manuelles}
		if contents of g is not {} then set groupes to groupes + 1
	end repeat
	set hauteurListe to hauteurListe + (groupes - 1) * ecartGroupes

	set liste to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {largeurListe, hauteurListe}}
	set y to hauteurListe
	if automatiques is not {} then
		set y to my titreGroupe(liste, y, largeurListe, item 10 of argv, item 11 of argv)
		set y to my lignesACocher(liste, y, automatiques, colonnes, item 8 of argv) - ecartGroupes
	end if
	if dependances is not {} then
		set y to my titreGroupe(liste, y, largeurListe, item 14 of argv, item 15 of argv)
		if deplie then
			set y to my lignesACocher(liste, y, dependances, colonnes, item 8 of argv)
		else
			set y to y - hauteurLigne
			set n to count of dependances
			set titreCase to ((current application's NSString's stringWithString:(item 16 of argv))'s stringByReplacingOccurrencesOfString:"%d" withString:(n as text)) as text
			set caseGroupe to current application's NSButton's checkboxWithTitle:titreCase target:(missing value) action:(missing value)
			caseGroupe's setFrame:{{0, y}, {colonneDetail - 12, hauteurLigne}}
			caseGroupe's setState:(my etatGroupe(dependances))
			liste's addSubview:caseGroupe
			set noms to {}
			repeat with l in dependances
				set end of noms to nom of l
			end repeat
			set AppleScript's text item delimiters to ", "
			set d to my texteGris(noms as text, 12)
			set AppleScript's text item delimiters to ""
			d's setFrame:{{colonneDetail, y + 4}, {xIgnore - 8 - colonneDetail, hauteurLigne - 8}}
			liste's addSubview:d
			liste's addSubview:(my petitBouton(item 17 of argv, "deplier:", 0, xOpen, y))
		end if
		set y to y - ecartGroupes
	end if
	if manuelles is not {} then
		set y to my titreGroupe(liste, y, largeurListe, item 12 of argv, item 13 of argv)
		repeat with l in manuelles
			set y to y - (my hauteurDe(l))
			set yLigne to y + (my hauteurDe(l)) - hauteurLigne
			set n to current application's NSTextField's labelWithString:(nom of l)
			n's setLineBreakMode:4
			n's setFrame:{{0, yLigne + 4}, {colonneDetail - 12, hauteurLigne - 8}}
			liste's addSubview:n
			my ajouterColonnes(liste, yLigne, l, colonnes, item 8 of argv)
			set b to my petitBouton(item 6 of argv, "ouvrir:", indice of l, xOpen, yLigne)
			liste's addSubview:b
			set item (indice of l) of openParLigne to b
			my ajouterInfo(liste, 0, y, xIgnore - 8, l)
			if ignorees contains (indice of l) then my griser(indice of l)
		end repeat
	end if

	-- En-tête : titre et texte
	set titre to current application's NSTextField's labelWithString:(item 1 of argv)
	titre's setFont:(current application's NSFont's boldSystemFontOfSize:15)
	set texte to current application's NSTextField's wrappingLabelWithString:(item 2 of argv)
	texte's setTextColor:(current application's NSColor's secondaryLabelColor())
	texte's setPreferredMaxLayoutWidth:largeurListe
	set hauteurTexte to (texte's fittingSize()'s height) as real

	-- Boutons, en bas à droite (Entrée = bouton principal, Échap = Later)
	set boutons to {}
	if automatiques is not {} or dependances is not {} then
		set end of boutons to my bouton(item 3 of argv, 1, return)
		set end of boutons to my bouton(item 4 of argv, 0, character id 27)
	else
		set end of boutons to my bouton(item 5 of argv, 0, return)
	end if

	-- Assemblage, de haut en bas
	set hauteurVisible to hauteurListe
	if hauteurVisible > hauteurMax then set hauteurVisible to hauteurMax
	set hauteur to marge + 22 + 6 + hauteurTexte + 16 + hauteurVisible + 20 + 32 + marge
	set fenetre to current application's NSPanel's alloc()'s initWithContentRect:{{0, 0}, {largeur, hauteur}} styleMask:1 backing:2 defer:false
	fenetre's setTitle:"check-updates"
	set contenu to fenetre's contentView()
	set y to hauteur - marge - 22
	titre's setFrame:{{marge, y}, {largeurListe, 22}}
	contenu's addSubview:titre
	set y to y - 6 - hauteurTexte
	texte's setFrame:{{marge, y}, {largeurListe, hauteurTexte}}
	contenu's addSubview:texte
	set y to y - 16 - hauteurVisible
	if hauteurVisible < hauteurListe then
		set defilement to current application's NSScrollView's alloc()'s initWithFrame:{{marge, y}, {largeurListe + 16, hauteurVisible}}
		defilement's setHasVerticalScroller:true
		defilement's setDrawsBackground:false
		defilement's setDocumentView:liste
		liste's scrollPoint:{0, hauteurListe}
		contenu's addSubview:defilement
	else
		liste's setFrameOrigin:{marge, y}
		contenu's addSubview:liste
	end if
	set x to largeur - marge
	repeat with b in boutons
		set b to contents of b
		set x to x - 110
		b's setFrame:{{x, marge}, {104, 32}}
		contenu's addSubview:b
	end repeat

	fenetre's setLevel:3 -- au-dessus des autres fenêtres
	fenetre's |center|()
	if reponsesTest is not {} then
		set reponse to item 1 of reponsesTest
		set reponsesTest to rest of reponsesTest
		return reponse
	end if
	fenetre's makeKeyAndOrderFront:(missing value)
	set reponse to (current application's NSApplication's sharedApplication()'s runModalForWindow:fenetre) as integer
	fenetre's orderOut:(missing value)
	return reponse
end afficher

-- Lignes avec une case à cocher ; renvoie la nouvelle position
on lignesACocher(vue, y, lignes, colonnes, titreIgnore)
	repeat with l in lignes
		set y to y - (my hauteurDe(l))
		set yLigne to y + (my hauteurDe(l)) - hauteurLigne
		set c to current application's NSButton's checkboxWithTitle:(nom of l) target:(missing value) action:(missing value)
		c's setFrame:{{0, yLigne}, {colonneDetail - 12, hauteurLigne}}
		set etat to item (indice of l) of etats
		if etat is missing value then
			if sorte of l is "A" then set etat to 1
			if sorte of l is not "A" then set etat to 0
		end if
		c's setState:etat
		vue's addSubview:c
		set item (indice of l) of casesParLigne to c
		my ajouterColonnes(vue, yLigne, l, colonnes, titreIgnore)
		my ajouterInfo(vue, 20, y, (xIgnore of colonnes) - 8, l) -- aligné sur le texte de la case
		if ignorees contains (indice of l) then my griser(indice of l)
	end repeat
	return y
end lignesACocher

-- Avant de déplier : l'état des cases, et celui de la case du groupe pour chaque dépendance
on memoriserEtats(dependances)
	repeat with k from 1 to count of casesParLigne
		set c to item k of casesParLigne
		if c is not missing value then set item k of etats to (c's state()) as integer
	end repeat
	if caseGroupe is not missing value then
		if ((caseGroupe's state()) as integer) is 0 then
			repeat with l in dependances
				set item (indice of l) of etats to 0
			end repeat
		end if
	end if
end memoriserEtats

on etatGroupe(dependances)
	repeat with l in dependances
		if sorte of l is "A" then return 1
	end repeat
	return 0
end etatGroupe

on hauteurDe(l)
	if info of l is "" then return hauteurLigne
	return hauteurLigne + hauteurInfo
end hauteurDe

on hauteurLignes(lignes)
	set h to 0
	repeat with l in lignes
		set h to h + (my hauteurDe(l))
	end repeat
	return h
end hauteurLignes

-- Bouton du bas : arrête la fenêtre avec son code (tag)
on bouton(titre, code, touche)
	set b to current application's NSButton's buttonWithTitle:titre target:me action:"fermer:"
	b's setTag:code
	b's setKeyEquivalent:touche
	return b
end bouton

on petitBouton(titre, action, k, x, y)
	set b to current application's NSButton's buttonWithTitle:titre target:me action:action
	b's setTag:k
	b's setControlSize:1 -- petit
	b's setFrame:{{x, y + 1}, {largeurBouton, hauteurLigne - 2}}
	return b
end petitBouton

on fermer:sender
	current application's NSApplication's sharedApplication()'s stopModalWithCode:((sender's tag()) as integer)
end fermer:

-- Bouton Show du groupe des dépendances : la fenêtre est redessinée, dépliée
on deplier:sender
	current application's NSApplication's sharedApplication()'s stopModalWithCode:2
end deplier:

-- Bouton Open : ouvre tout de suite, la fenêtre reste affichée
on ouvrir:sender
	do shell script (item ((sender's tag()) as integer) of commandes)
	sender's setTitle:libelleOuvert
end ouvrir:

-- Bouton Ignore : la ligne est grisée et sera ignorée, quel que soit le bouton du bas
on ignorer:sender
	set k to (sender's tag()) as integer
	if ignorees does not contain k then set end of ignorees to k
	my griser(k)
end ignorer:

on griser(k)
	set b to item k of ignoreParLigne
	if b is not missing value then
		b's setTitle:libelleIgnore
		b's setEnabled:false
	end if
	set c to item k of casesParLigne
	if c is not missing value then
		c's setState:0
		c's setEnabled:false
	end if
	set b to item k of openParLigne
	if b is not missing value then b's setEnabled:false
end griser

on texteGris(texte, taille)
	set d to current application's NSTextField's labelWithString:texte
	d's setTextColor:(current application's NSColor's secondaryLabelColor())
	d's setFont:(current application's NSFont's monospacedDigitSystemFontOfSize:taille weight:0)
	d's setLineBreakMode:4 -- tronque la fin si c'est trop long
	return d
end texteGris

-- Description sous la ligne (petite, grise), si la source la connaît
on ajouterInfo(vue, x, y, xFin, l)
	if info of l is "" then return
	set t to current application's NSTextField's labelWithString:(info of l)
	t's setFont:(current application's NSFont's systemFontOfSize:11)
	t's setTextColor:(current application's NSColor's secondaryLabelColor())
	t's setLineBreakMode:4
	t's setFrame:{{x, y + 2}, {xFin - x, hauteurInfo + 2}}
	vue's addSubview:t
end ajouterInfo

-- Détail (gris), étiquette (couleur) et bouton Ignore d'une ligne
on ajouterColonnes(vue, y, l, colonnes, titreIgnore)
	if detail of l is not "" then
		set d to my texteGris(detail of l, 12)
		d's setFrame:{{colonneDetail, y + 4}, {largeurDetail of colonnes, hauteurLigne - 8}}
		vue's addSubview:d
	end if
	if etiquette of l is not "" then
		set e to current application's NSTextField's labelWithString:(etiquette of l)
		e's setFont:(current application's NSFont's boldSystemFontOfSize:11)
		e's setAlignment:2 -- centré
		if etiquette of l is "security" then
			e's setTextColor:(current application's NSColor's systemRedColor())
		else
			e's setTextColor:(current application's NSColor's systemOrangeColor())
		end if
		e's setFrame:{{xEtiquette of colonnes, y + 5}, {largeurEtiquette, hauteurLigne - 10}}
		vue's addSubview:e
	end if
	set b to my petitBouton(titreIgnore, "ignorer:", indice of l, xIgnore of colonnes, y)
	vue's addSubview:b
	set item (indice of l) of ignoreParLigne to b
end ajouterColonnes

-- Titre du groupe (gras) suivi de son explication (gris) ; renvoie la nouvelle position
on titreGroupe(vue, y, largeurDispo, titre, explication)
	set NSFont to current application's NSFont
	set texte to titre & "  " & explication
	set s to current application's NSMutableAttributedString's alloc()'s initWithString:texte
	s's addAttribute:(current application's NSFontAttributeName) value:(NSFont's systemFontOfSize:12) range:{0, length of texte}
	s's addAttribute:(current application's NSForegroundColorAttributeName) value:(current application's NSColor's secondaryLabelColor()) range:{0, length of texte}
	s's addAttribute:(current application's NSFontAttributeName) value:(NSFont's boldSystemFontOfSize:13) range:{0, length of titre}
	s's addAttribute:(current application's NSForegroundColorAttributeName) value:(current application's NSColor's labelColor()) range:{0, length of titre}
	set y to y - hauteurTitreGroupe
	set t to current application's NSTextField's labelWithAttributedString:s
	t's setFrame:{{0, y + 4}, {largeurDispo, hauteurTitreGroupe - 10}}
	vue's addSubview:t
	return y
end titreGroupe
