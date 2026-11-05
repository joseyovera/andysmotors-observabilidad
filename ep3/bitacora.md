# Bitácora de escenarios · Sesión de prueba EP3

Fecha: 04-11-2026 · Tráfico: generar_trafico.py --hora-inicio 9 (desde 21:04)

## Línea base

- 21:25 a 21:44 · Sin fallas. Solo errores normales del gateway (~1 %).

## agenda_silenciosa (negocio)

- Inicio: 21:44
- Término: 21:53
- Qué se observó: alarma En alarma a las 21:45:06 (1 min después). 36 descartados en 5 min. Agenda seguía respondiendo 201.
- Alarma volvió a OK a las 21:58 (correo OK recibido).
- 298 agendamientos perdidos (244 clientes) en 5 sucursales; la más afectada fue Viña del Mar (66).

## gateway_lento (técnico)

- Inicio: 21:54
- Término: 22:04
- Qué se observó: latencia p95 de pagos y gateway subió de ~390 ms a ~7.600 ms; resto de plataformas sin cambios (~5–18 ms). Aumentó la métrica PagosLentos.

## crm_huerfano (negocio)

- Inicio: 22:05
- Término: 22:11
- Qué se observó: 294 oportunidades sin cliente en 5 min (pico 22:05). No generó errores HTTP ni cambios en CPU; solo visible en los logs.
