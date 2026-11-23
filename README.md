# Ritmo (juego rítmico de 5 trastes para Android)

Juego original hecho con **Godot 4.3**. Highway con 5 trastes, rachas, multiplicador, modo historia por zonas y videos al completar cada zona. Las canciones las pones tú.

> Estado: **prototipo sin probar en dispositivo**. Fue escrito sin poder ejecutar Godot, así que es posible que haya errores a corregir al abrirlo por primera vez.

## Estructura

- `project.godot`, `main.tscn`: proyecto y escena principal.
- `scripts/main.gd`: menús, selección de canciones, modo historia, videos y resultados.
- `scripts/game.gd`: gameplay (highway, toques, puntuación, pausa).
- `scripts/chart_parser.gd`: lector de `notes.chart` (formato Clone Hero) y carga de audio.
- `story/story.json`: zonas, canciones, estrellas mínimas y video por zona.

## Canciones

Cada canción es una carpeta con:

```
mi_cancion_1/
  notes.chart   (obligatorio)
  song.ini      (opcional: name = ..., artist = ...)
  song.ogg      (o guitar.ogg / song.mp3)
```

Se buscan en: `user://songs/`, `res://songs/` y `/storage/emulated/0/RitmoSongs/` (el juego pide permiso de almacenamiento al iniciar).
Solo se leen las notas de los 5 trastes (0-4); los toques forzados y notas "open" se ignoran por ahora.

## Modo historia

Edita `story/story.json`. El nombre en `songs` es el nombre de la carpeta de la canción. Al terminar todas las canciones de una zona con las estrellas mínimas, se reproduce el `video` de esa zona.

**Videos:** Godot solo reproduce de forma nativa **Ogg Theora (.ogv)**. Convierte con ffmpeg:

```
ffmpeg -i entrada.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 zona1.ogv
```

## Controles

- Móvil: toca los 5 círculos de abajo. No hace falta rasgar.
- PC (pruebas): teclas A S D F G.

## Exportar el APK

1. Abre el proyecto en Godot 4.3 y descarga las plantillas de exportación.
2. Configura el Android SDK/JDK en Editor Settings.
3. Project > Export > Android > Export Project (APK con keystore de depuración).

## Pendiente

Star power, notas sostenidas, calibración de latencia en menú, selector de carpeta de canciones y GitHub Actions para compilar el APK.
