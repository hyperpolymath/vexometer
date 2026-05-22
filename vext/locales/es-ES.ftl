# SPDX-License-Identifier: MPL-2.0
# Spanish (Spain) translations for vext

# Notification messages
notification-commit = { $author } confirmó en { $branch }: { $message }
notification-push = { $author } envió { $count } confirmaciones a { $branch }
notification-merge = { $author } fusionó { $source } en { $target }

# Status messages
status-connected = Conectado al servidor IRC { $server }
status-disconnected = Desconectado del servidor IRC { $server }
status-joining = Uniéndose al canal { $channel }
status-rate-limited = Limitado en { $target }, mensaje en cola

# Error messages
error-connection-failed = Error al conectar con { $server }: { $reason }
error-invalid-target = Destino IRC inválido: { $target }
error-send-failed = Error al enviar mensaje a { $target }

# Help messages
help-usage = Uso: vextd [OPCIONES]
help-listen = Dirección de escucha para notificaciones UDP (predeterminado: 127.0.0.1:6659)
help-server = Servidor IRC predeterminado (predeterminado: irc.libera.chat)
