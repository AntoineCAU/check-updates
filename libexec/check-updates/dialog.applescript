-- Fenêtre à boutons (AppKit) : osascript lancé depuis un terminal ou launchd ne peut pas
-- afficher un « display dialog » classique sans passer au premier plan.
-- Arguments : titre, texte, puis les boutons (le dernier est celui par défaut).
-- Affiche le bouton cliqué.
use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

on run argv
	set app_ to current application's NSApplication's sharedApplication()
	app_'s setActivationPolicy:1 -- accessory : osascript a le droit d'afficher une fenêtre, sans icône dans le Dock
	app_'s activateIgnoringOtherApps:true

	set alerte to current application's NSAlert's alloc()'s init()
	alerte's setMessageText:(item 1 of argv)
	alerte's setInformativeText:(item 2 of argv)
	alerte's setIcon:(current application's NSImage's imageWithSystemSymbolName:"arrow.down.circle" accessibilityDescription:(missing value))
	set boutons to reverse of (items 3 thru -1 of argv) -- NSAlert : le premier bouton ajouté est celui par défaut
	repeat with b in boutons
		alerte's addButtonWithTitle:(b as text)
	end repeat
	alerte's layout()
	alerte's |window|()'s setLevel:3 -- au-dessus des autres fenêtres

	set r to ((alerte's runModal()) as integer) - 1000 + 1
	return item r of boutons
end run
