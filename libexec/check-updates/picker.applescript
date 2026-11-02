-- Fenêtre à cases à cocher (AppKit), une case par mise à jour, en deux groupes :
-- celles que check-updates installe lui-même, et celles à faire soi-même (Réglages, app, site).
-- Arguments : titre, consigne, bouton valider, bouton annuler, titre du groupe automatique,
-- titre du groupe manuel, puis les libellés automatiques, « --manual-- », les libellés manuels.
-- Affiche les libellés cochés, un par ligne (rien si annulé).
use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property largeur : 600
property hauteurLigne : 24
property hauteurTitre : 28

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

	-- Répartition des libellés entre les deux groupes
	set automatiques to {}
	set manuelles to {}
	set dansManuelles to false
	repeat with i from 7 to count of argv
		set l to item i of argv
		if l is "--manual--" then
			set dansManuelles to true
		else if dansManuelles then
			set end of manuelles to l
		else
			set end of automatiques to l
		end if
	end repeat

	-- Lignes de haut en bas : {type, texte}
	set lignes to {}
	if (count of automatiques) > 0 then
		set end of lignes to {"titre", item 5 of argv}
		repeat with l in automatiques
			set end of lignes to {"case", l as text}
		end repeat
	end if
	if (count of manuelles) > 0 then
		set end of lignes to {"titre", item 6 of argv}
		repeat with l in manuelles
			set end of lignes to {"case", l as text}
		end repeat
	end if

	set hauteurTotale to 0
	repeat with ligne in lignes
		if item 1 of ligne is "titre" then
			set hauteurTotale to hauteurTotale + hauteurTitre
		else
			set hauteurTotale to hauteurTotale + hauteurLigne
		end if
	end repeat

	set vue to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {largeur, hauteurTotale}}
	set cases to {}
	set y to hauteurTotale
	repeat with ligne in lignes
		if item 1 of ligne is "titre" then
			set y to y - hauteurTitre
			set t to current application's NSTextField's labelWithString:(item 2 of ligne)
			t's setFont:(current application's NSFont's boldSystemFontOfSize:13)
			t's setFrame:{{0, y}, {largeur, hauteurTitre - 6}}
			vue's addSubview:t
		else
			set y to y - hauteurLigne
			set c to current application's NSButton's checkboxWithTitle:(item 2 of ligne) target:(missing value) action:(missing value)
			c's setFrame:{{12, y}, {largeur - 12, hauteurLigne}}
			vue's addSubview:c
			set end of cases to c
		end if
	end repeat

	-- Au-delà d'une quinzaine de lignes, la liste défile
	if hauteurTotale > 15 * hauteurLigne then
		set defilement to current application's NSScrollView's alloc()'s initWithFrame:{{0, 0}, {largeur + 20, 15 * hauteurLigne}}
		defilement's setHasVerticalScroller:true
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
		if ((c's state()) as integer) is 1 then set end of choix to (c's title()) as text
	end repeat
	set AppleScript's text item delimiters to linefeed
	return choix as text
end run
