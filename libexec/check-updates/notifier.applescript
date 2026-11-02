-- Petite app construite sur le Mac par check-updates (osacompile) pour afficher ses
-- notifications : un clic sur une notification lancée par osascript ouvre l'Éditeur de
-- scripts, un clic sur celles de cette app la relance, et elle exécute alors la commande
-- associée à la dernière notification (rouvrir la liste).
--
-- check-updates écrit « titre⏎texte » dans Caches/check-updates/notification puis lance
-- l'app : elle l'affiche et efface le fichier. Lancée sans notification en attente (par
-- un clic), elle exécute Caches/check-updates/notification-click s'il n'est pas vide.

on run
	set dossier to (POSIX path of (path to library folder from user domain)) & "Caches/check-updates/"
	set attente to dossier & "notification"
	set lignes to {}
	try
		set lignes to paragraphs of (read (POSIX file attente) as «class utf8»)
		do shell script "rm -f " & quoted form of attente
	end try
	if (count of lignes) ≥ 2 then
		display notification (item 2 of lignes) with title (item 1 of lignes)
		delay 1
	else
		try
			set commande to read (POSIX file (dossier & "notification-click")) as «class utf8»
			if commande is not "" then do shell script commande & " >/dev/null 2>&1 &"
		end try
	end if
end run
