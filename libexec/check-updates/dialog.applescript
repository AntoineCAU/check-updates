-- Fenêtre à boutons, dessinée ici (NSPanel) comme la liste des mises à jour : un
-- « display dialog » lancé depuis un terminal ou launchd ne s'affiche pas, et NSAlert
-- réserve toujours la place d'une icône.
-- Arguments : titre, texte, puis les boutons (le dernier est celui par défaut).
-- Affiche le bouton cliqué.
use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property largeur : 440
property marge : 20

on run argv
	set app_ to current application's NSApplication's sharedApplication()
	app_'s setActivationPolicy:1 -- accessory : osascript a le droit d'afficher une fenêtre, sans icône dans le Dock
	app_'s activateIgnoringOtherApps:true

	set largeurTexte to largeur - 2 * marge
	set titre to current application's NSTextField's wrappingLabelWithString:(item 1 of argv)
	titre's setFont:(current application's NSFont's boldSystemFontOfSize:15)
	titre's setPreferredMaxLayoutWidth:largeurTexte
	set hauteurTitre to (titre's fittingSize()'s height) as real
	set texte to current application's NSTextField's wrappingLabelWithString:(item 2 of argv)
	texte's setTextColor:(current application's NSColor's secondaryLabelColor())
	texte's setPreferredMaxLayoutWidth:largeurTexte
	set hauteurTexte to (texte's fittingSize()'s height) as real

	set hauteur to marge + hauteurTitre + 8 + hauteurTexte + 20 + 32 + marge
	set fenetre to current application's NSPanel's alloc()'s initWithContentRect:{{0, 0}, {largeur, hauteur}} styleMask:1 backing:2 defer:false
	fenetre's setTitle:"check-updates"
	set contenu to fenetre's contentView()
	set y to hauteur - marge - hauteurTitre
	titre's setFrame:{{marge, y}, {largeurTexte, hauteurTitre}}
	contenu's addSubview:titre
	set y to y - 8 - hauteurTexte
	texte's setFrame:{{marge, y}, {largeurTexte, hauteurTexte}}
	contenu's addSubview:texte

	-- Boutons en bas à droite, le dernier argument (par défaut) le plus à droite
	set libelles to items 3 thru -1 of argv
	set n to count of libelles
	set x to largeur - marge
	repeat with i from n to 1 by -1
		set b to (current application's NSButton's buttonWithTitle:(item i of libelles) target:me action:"fermer:")
		b's setTag:i
		if i is n then b's setKeyEquivalent:return
		set l to ((b's fittingSize()'s width) as real) + 24
		if l < 90 then set l to 90
		set x to x - l
		b's setFrame:{{x, marge}, {l, 32}}
		contenu's addSubview:b
		set x to x - 8
	end repeat

	fenetre's setLevel:3 -- au-dessus des autres fenêtres
	fenetre's |center|()
	fenetre's makeKeyAndOrderFront:(missing value)
	set reponse to (app_'s runModalForWindow:fenetre) as integer
	fenetre's orderOut:(missing value)
	return item reponse of libelles
end run

on fermer:sender
	current application's NSApplication's sharedApplication()'s stopModalWithCode:((sender's tag()) as integer)
end fermer:
