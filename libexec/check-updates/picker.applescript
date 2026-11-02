-- Liste des mises à jour (AppKit), en deux groupes :
--   automatiques : une case à cocher (pré-cochée), installées après « Update » ;
--   à faire soi-même : un bouton « Open » qui ouvre tout de suite les Réglages, l'app ou le site.
-- Arguments : titre, texte, bouton Update, bouton Later, bouton Done (s'il n'y a rien à cocher),
-- bouton Open, libellé « ouvert », titre et explication du groupe automatique, titre et
-- explication du groupe manuel, puis une ligne par mise à jour :
--   « A <tab> nom <tab> détail » ou « M <tab> nom <tab> détail <tab> commande ».
-- Affiche les numéros (à partir de 1) des lignes automatiques cochées si on valide.
use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property largeur : 620
property colonneDetail : 230
property largeurBouton : 76
property hauteurLigne : 26
property hauteurTitre : 30
property ecartGroupes : 10
property premiereLigne : 12 -- index du premier argument « ligne »

property commandes : {} -- commandes des boutons Open, par numéro (tag)
property libelleOuvert : ""

on run argv
	set app_ to current application's NSApplication's sharedApplication()
	app_'s setActivationPolicy:1 -- accessory : osascript a le droit d'afficher une fenêtre, sans icône dans le Dock
	app_'s activateIgnoringOtherApps:true

	set automatiques to {}
	set manuelles to {}
	set AppleScript's text item delimiters to tab
	repeat with i from premiereLigne to count of argv
		set champs to text items of (item i of argv)
		set ligne to {indice:(i - premiereLigne + 1), nom:(item 2 of champs), detail:"", commande:""}
		if (count of champs) > 2 then set detail of ligne to item 3 of champs
		if item 1 of champs is "A" then
			set end of automatiques to ligne
		else
			if (count of champs) > 3 then set commande of ligne to item 4 of champs
			set end of manuelles to ligne
		end if
	end repeat
	set AppleScript's text item delimiters to ""
	set libelleOuvert to item 7 of argv

	set alerte to current application's NSAlert's alloc()'s init()
	alerte's setMessageText:(item 1 of argv)
	alerte's setInformativeText:(item 2 of argv)
	alerte's setIcon:(current application's NSImage's alloc()'s initWithSize:{1, 1}) -- pas d'icône
	if automatiques is not {} then
		alerte's addButtonWithTitle:(item 3 of argv)
		alerte's addButtonWithTitle:(item 4 of argv)
	else
		alerte's addButtonWithTitle:(item 5 of argv)
	end if

	set hauteurTotale to 0
	if automatiques is not {} then set hauteurTotale to hauteurTotale + hauteurTitre + (count of automatiques) * hauteurLigne
	if manuelles is not {} then set hauteurTotale to hauteurTotale + hauteurTitre + (count of manuelles) * hauteurLigne
	if automatiques is not {} and manuelles is not {} then set hauteurTotale to hauteurTotale + ecartGroupes

	set vue to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {largeur, hauteurTotale}}
	set cases to {}
	set y to hauteurTotale
	if automatiques is not {} then
		set y to my titreGroupe(vue, y, item 8 of argv, item 9 of argv)
		repeat with l in automatiques
			set y to y - hauteurLigne
			set c to current application's NSButton's checkboxWithTitle:(nom of l) target:(missing value) action:(missing value)
			c's setFrame:{{8, y}, {colonneDetail - 16, hauteurLigne}}
			c's setState:1
			vue's addSubview:c
			my ajouterDetail(vue, y, detail of l, largeur - colonneDetail)
			set end of cases to {c, indice of l}
		end repeat
		set y to y - ecartGroupes
	end if
	if manuelles is not {} then
		set y to my titreGroupe(vue, y, item 10 of argv, item 11 of argv)
		repeat with l in manuelles
			set y to y - hauteurLigne
			set n to current application's NSTextField's labelWithString:(nom of l)
			n's setLineBreakMode:4
			n's setFrame:{{8, y + 4}, {colonneDetail - 16, hauteurLigne - 8}}
			vue's addSubview:n
			my ajouterDetail(vue, y, detail of l, largeur - colonneDetail - largeurBouton - 8)
			set end of commandes to commande of l
			set b to current application's NSButton's buttonWithTitle:(item 6 of argv) target:me action:"ouvrir:"
			b's setTag:(count of commandes)
			b's setControlSize:1 -- petit
			b's setFrame:{{largeur - largeurBouton, y + 1}, {largeurBouton, hauteurLigne - 2}}
			vue's addSubview:b
		end repeat
	end if

	-- Au-delà d'une quinzaine de lignes, la liste défile
	if hauteurTotale > 15 * hauteurLigne then
		set defilement to current application's NSScrollView's alloc()'s initWithFrame:{{0, 0}, {largeur + 20, 15 * hauteurLigne}}
		defilement's setHasVerticalScroller:true
		defilement's setDrawsBackground:false
		defilement's setDocumentView:vue
		vue's scrollPoint:{0, hauteurTotale}
		alerte's setAccessoryView:defilement
	else
		alerte's setAccessoryView:vue
	end if
	alerte's layout()
	alerte's |window|()'s setLevel:3 -- au-dessus des autres fenêtres

	set reponse to (alerte's runModal()) as integer
	if automatiques is {} or reponse is not 1000 then return "" -- 1000 = premier bouton (Update)
	set choix to {}
	repeat with c in cases
		if (((item 1 of c)'s state()) as integer) is 1 then set end of choix to (item 2 of c) as text
	end repeat
	set AppleScript's text item delimiters to linefeed
	return choix as text
end run

-- Bouton Open : ouvre tout de suite, la fenêtre reste affichée
on ouvrir:sender
	do shell script (item ((sender's tag()) as integer) of commandes)
	sender's setTitle:libelleOuvert
end ouvrir:

-- Titre du groupe (gras) suivi de son explication (gris) ; renvoie la nouvelle position
on titreGroupe(vue, y, titre, explication)
	set NSFont to current application's NSFont
	set texte to titre & "  " & explication
	set s to current application's NSMutableAttributedString's alloc()'s initWithString:texte
	s's addAttribute:(current application's NSFontAttributeName) value:(NSFont's systemFontOfSize:12) range:{0, length of texte}
	s's addAttribute:(current application's NSForegroundColorAttributeName) value:(current application's NSColor's secondaryLabelColor()) range:{0, length of texte}
	s's addAttribute:(current application's NSFontAttributeName) value:(NSFont's boldSystemFontOfSize:13) range:{0, length of titre}
	s's addAttribute:(current application's NSForegroundColorAttributeName) value:(current application's NSColor's labelColor()) range:{0, length of titre}
	set y to y - hauteurTitre
	set t to current application's NSTextField's labelWithAttributedString:s
	t's setFrame:{{0, y + 4}, {largeur, hauteurTitre - 10}}
	vue's addSubview:t
	return y
end titreGroupe

-- Versions (et précision éventuelle), en gris dans la colonne de droite
on ajouterDetail(vue, y, detail, largeurDispo)
	if detail is "" then return
	set d to current application's NSTextField's labelWithString:detail
	d's setTextColor:(current application's NSColor's secondaryLabelColor())
	d's setFont:(current application's NSFont's monospacedDigitSystemFontOfSize:12 weight:0)
	d's setLineBreakMode:4 -- tronque la fin si c'est trop long
	d's setFrame:{{colonneDetail, y + 4}, {largeurDispo, hauteurLigne - 8}}
	vue's addSubview:d
end ajouterDetail
