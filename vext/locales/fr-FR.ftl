# SPDX-License-Identifier: MPL-2.0
# French (France) translations for vext

# Notification messages
notification-commit = { $author } a validé sur { $branch } : { $message }
notification-push = { $author } a poussé { $count } validations vers { $branch }
notification-merge = { $author } a fusionné { $source } dans { $target }

# Status messages
status-connected = Connecté au serveur IRC { $server }
status-disconnected = Déconnecté du serveur IRC { $server }
status-joining = Rejoindre le canal { $channel }
status-rate-limited = Limité sur { $target }, message en file d'attente

# Error messages
error-connection-failed = Échec de la connexion à { $server } : { $reason }
error-invalid-target = Cible IRC invalide : { $target }
error-send-failed = Échec de l'envoi du message à { $target }

# Help messages
help-usage = Utilisation : vextd [OPTIONS]
help-listen = Adresse d'écoute pour les notifications UDP (par défaut : 127.0.0.1:6659)
help-server = Serveur IRC par défaut (par défaut : irc.libera.chat)
