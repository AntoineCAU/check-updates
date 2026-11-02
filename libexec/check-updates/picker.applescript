-- Liste des mises à jour, dans une fenêtre dessinée ici (NSPanel) plutôt qu'une alerte :
-- NSAlert réserve toujours la place d'une icône. Deux groupes :
--   automatiques : une case à cocher, installées après « Update » (pré-cochée, sauf version majeure) ;
--   à faire soi-même : un bouton « Open » qui ouvre tout de suite les Réglages, l'app ou le site.
-- Chaque ligne a aussi un bouton « Ignore » (ignorer cette version).
-- Arguments : titre, texte, boutons Update, Later, Done (s'il n'y a rien à cocher), Open,
-- libellé « ouvert », Ignore, libellé « ignoré », titre et explication du groupe automatique,
-- titre et explication du groupe manuel, puis une ligne par mise à jour :
--   « A|B <tab> nom <tab> détail <tab> étiquette »  (A cochée, B non cochée)
--   « M <tab> nom <tab> détail <tab> étiquette <tab> commande »
-- Affiche une ligne par décision : « i N » pour chaque ligne ignorée, et si on valide,
-- « u N » pour chaque case cochée (N = numéro de la ligne, à partir de 1).
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
property hauteurTitreGroupe : 30
property ecartGroupes : 10
property lignesVisibles : 14
property premiereLigne : 14 -- index du premier argument « ligne »

property commandes : {} -- commande du bouton Open de chaque ligne (missing value sinon)
property casesParLigne : {} -- case à cocher de chaque ligne (missing value sinon)
property openParLigne : {} -- bouton Open de chaque ligne (missing value sinon)
property ignorees : {}
property libelleOuvert : ""
property libelleIgnore : ""

on run argv
	set app_ to current application's NSApplication's sharedApplication()
	app_'s setActivationPolicy:1 -- accessory : osascript a le droit d'afficher une fenêtre, sans icône dans le Dock
	app_'s activateIgnoringOtherApps:true

	set automatiques to {}
	set manuelles to {}
	set AppleScript's text item delimiters to tab
	repeat with i from premiereLigne to count of argv
		set champs to text items of (item i of argv)
		set ligne to {indice:(i - premiereLigne + 1), sorte:(item 1 of champs), nom:(item 2 of champs), detail:"", etiquette:"", commande:""}
		if (count of champs) > 2 then set detail of ligne to item 3 of champs
		if (count of champs) > 3 then set etiquette of ligne to item 4 of champs
		if (count of champs) > 4 then set commande of ligne to item 5 of champs
		if sorte of ligne is "M" then
			set end of manuelles to ligne
		else
			set end of automatiques to ligne
		end if
		set end of commandes to commande of ligne
		set end of casesParLigne to missing value
		set end of openParLigne to missing value
	end repeat
	set AppleScript's text item delimiters to ""
	set libelleOuvert to item 7 of argv
	set libelleIgnore to item 9 of argv

	-- Colonnes de droite à gauche : Open, Ignore, étiquette, puis le détail
	set largeurListe to largeur - 2 * marge
	set xOpen to largeurListe - largeurBouton
	set xIgnore to xOpen - 6 - largeurBouton
	set xEtiquette to xIgnore - 8 - largeurEtiquette
	set largeurDetail to xEtiquette - 8 - colonneDetail

	set hauteurListe to 0
	if automatiques is not {} then set hauteurListe to hauteurListe + hauteurTitreGroupe + (count of automatiques) * hauteurLigne
	if manuelles is not {} then set hauteurListe to hauteurListe + hauteurTitreGroupe + (count of manuelles) * hauteurLigne
	if automatiques is not {} and manuelles is not {} then set hauteurListe to hauteurListe + ecartGroupes

	set liste to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {largeurListe, hauteurListe}}
	set y to hauteurListe
	if automatiques is not {} then
		set y to my titreGroupe(liste, y, largeurListe, item 10 of argv, item 11 of argv)
		repeat with l in automatiques
			set y to y - hauteurLigne
			set c to current application's NSButton's checkboxWithTitle:(nom of l) target:(missing value) action:(missing value)
			c's setFrame:{{0, y}, {colonneDetail - 12, hauteurLigne}}
			if sorte of l is "A" then c's setState:1
			liste's addSubview:c
			set item (indice of l) of casesParLigne to c
			my ajouterColonnes(liste, y, l, largeurDetail, xEtiquette, xIgnore, item 8 of argv)
		end repeat
		set y to y - ecartGroupes
	end if
	if manuelles is not {} then
		set y to my titreGroupe(liste, y, largeurListe, item 12 of argv, item 13 of argv)
		repeat with l in manuelles
			set y to y - hauteurLigne
			set n to current application's NSTextField's labelWithString:(nom of l)
			n's setLineBreakMode:4
			n's setFrame:{{0, y + 4}, {colonneDetail - 12, hauteurLigne - 8}}
			liste's addSubview:n
			my ajouterColonnes(liste, y, l, largeurDetail, xEtiquette, xIgnore, item 8 of argv)
			set b to my petitBouton(item 6 of argv, "ouvrir:", indice of l, xOpen, y)
			liste's addSubview:b
			set item (indice of l) of openParLigne to b
		end repeat
	end if
	set hauteurVisible to hauteurListe
	if hauteurVisible > lignesVisibles * hauteurLigne then set hauteurVisible to lignesVisibles * hauteurLigne

	-- En-tête : titre et texte
	set titre to current application's NSTextField's labelWithString:(item 1 of argv)
	titre's setFont:(current application's NSFont's boldSystemFontOfSize:15)
	set texte to current application's NSTextField's wrappingLabelWithString:(item 2 of argv)
	texte's setTextColor:(current application's NSColor's secondaryLabelColor())
	texte's setPreferredMaxLayoutWidth:largeurListe
	set hauteurTexte to (texte's fittingSize()'s height) as real

	-- Boutons, en bas à droite (Entrée = bouton principal, Échap = Later)
	set boutons to {}
	if automatiques is not {} then
		set end of boutons to my bouton(item 3 of argv, 1, return)
		set end of boutons to my bouton(item 4 of argv, 0, character id 27)
	else
		set end of boutons to my bouton(item 5 of argv, 0, return)
	end if

	-- Assemblage, de haut en bas
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
	fenetre's makeKeyAndOrderFront:(missing value)
	set reponse to (app_'s runModalForWindow:fenetre) as integer
	fenetre's orderOut:(missing value)

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
	end if
	set AppleScript's text item delimiters to linefeed
	return sortie as text
end run

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

-- Bouton Open : ouvre tout de suite, la fenêtre reste affichée
on ouvrir:sender
	do shell script (item ((sender's tag()) as integer) of commandes)
	sender's setTitle:libelleOuvert
end ouvrir:

-- Bouton Ignore : la ligne est grisée et sera ignorée, quel que soit le bouton du bas
on ignorer:sender
	set k to (sender's tag()) as integer
	set end of ignorees to k
	sender's setTitle:libelleIgnore
	sender's setEnabled:false
	set c to item k of casesParLigne
	if c is not missing value then
		c's setState:0
		c's setEnabled:false
	end if
	set b to item k of openParLigne
	if b is not missing value then b's setEnabled:false
end ignorer:

-- Détail (gris), étiquette (couleur) et bouton Ignore d'une ligne
on ajouterColonnes(vue, y, l, largeurDetail, xEtiquette, xIgnore, titreIgnore)
	if detail of l is not "" then
		set d to current application's NSTextField's labelWithString:(detail of l)
		d's setTextColor:(current application's NSColor's secondaryLabelColor())
		d's setFont:(current application's NSFont's monospacedDigitSystemFontOfSize:12 weight:0)
		d's setLineBreakMode:4 -- tronque la fin si c'est trop long
		d's setFrame:{{colonneDetail, y + 4}, {largeurDetail, hauteurLigne - 8}}
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
		e's setFrame:{{xEtiquette, y + 5}, {largeurEtiquette, hauteurLigne - 10}}
		vue's addSubview:e
	end if
	vue's addSubview:(my petitBouton(titreIgnore, "ignorer:", indice of l, xIgnore, y))
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
