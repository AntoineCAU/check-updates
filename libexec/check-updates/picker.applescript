-- Liste à cocher des mises à jour (AppKit), en deux groupes : celles que check-updates
-- installe lui-même (pré-cochées) et celles à faire soi-même (Réglages, app, site).
-- Arguments : titre, texte, bouton valider, bouton plus tard, titre et explication du groupe
-- automatique, titre et explication du groupe manuel, puis une ligne par mise à jour :
-- « A|M <tab> nom <tab> détail ». Affiche les numéros (à partir de 1) des lignes cochées.
use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property largeur : 620
property colonneDetail : 230
property hauteurLigne : 24
property hauteurTitre : 30
property ecartGroupes : 10

on run argv
	set app_ to current application's NSApplication's sharedApplication()
	app_'s setActivationPolicy:1 -- accessory : osascript a le droit d'afficher une fenêtre, sans icône dans le Dock
	app_'s activateIgnoringOtherApps:true

	set alerte to current application's NSAlert's alloc()'s init()
	alerte's setMessageText:(item 1 of argv)
	alerte's setInformativeText:(item 2 of argv)
	alerte's addButtonWithTitle:(item 3 of argv)
	alerte's addButtonWithTitle:(item 4 of argv)
	alerte's setIcon:(current application's NSImage's imageWithSystemSymbolName:"arrow.down.circle" accessibilityDescription:(missing value))

	set automatiques to {}
	set manuelles to {}
	set AppleScript's text item delimiters to tab
	repeat with i from 9 to count of argv
		set champs to text items of (item i of argv)
		set ligne to {indice:(i - 8), nom:(item 2 of champs), detail:""}
		if (count of champs) > 2 then set detail of ligne to item 3 of champs
		if item 1 of champs is "A" then
			set end of automatiques to ligne
		else
			set end of manuelles to ligne
		end if
	end repeat
	set AppleScript's text item delimiters to ""

	set hauteurTotale to 0
	if automatiques is not {} then set hauteurTotale to hauteurTotale + hauteurTitre + (count of automatiques) * hauteurLigne
	if manuelles is not {} then set hauteurTotale to hauteurTotale + hauteurTitre + (count of manuelles) * hauteurLigne
	if automatiques is not {} and manuelles is not {} then set hauteurTotale to hauteurTotale + ecartGroupes

	set vue to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {largeur, hauteurTotale}}
	set cases to {}
	set y to hauteurTotale
	if automatiques is not {} then
		set y to my groupe(vue, y, item 5 of argv, item 6 of argv, automatiques, true, cases)
		set y to y - ecartGroupes
	end if
	if manuelles is not {} then set y to my groupe(vue, y, item 7 of argv, item 8 of argv, manuelles, false, cases)

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

	if ((alerte's runModal()) as integer) is not 1000 then return "" -- 1000 = premier bouton
	set choix to {}
	repeat with c in cases
		if (((item 1 of c)'s state()) as integer) is 1 then set end of choix to (item 2 of c) as text
	end repeat
	set AppleScript's text item delimiters to linefeed
	return choix as text
end run

-- Titre du groupe (gras) suivi de son explication (gris), puis une case par ligne.
-- Renvoie la nouvelle position verticale.
on groupe(vue, y, titre, explication, lignes, coche, cases)
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

	repeat with l in lignes
		set y to y - hauteurLigne
		set c to current application's NSButton's checkboxWithTitle:(nom of l) target:(missing value) action:(missing value)
		c's setFrame:{{8, y}, {colonneDetail - 16, hauteurLigne}}
		if coche then c's setState:1
		vue's addSubview:c
		if detail of l is not "" then
			set d to current application's NSTextField's labelWithString:(detail of l)
			d's setTextColor:(current application's NSColor's secondaryLabelColor())
			d's setFont:(NSFont's monospacedDigitSystemFontOfSize:12 weight:0)
			d's setLineBreakMode:4 -- tronque la fin si c'est trop long
			d's setFrame:{{colonneDetail, y + 3}, {largeur - colonneDetail, hauteurLigne - 6}}
			vue's addSubview:d
		end if
		set end of cases to {c, indice of l}
	end repeat
	return y
end groupe
