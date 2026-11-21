// =====================================================================
//  metricas-negocio.js · AndysMotors EP4 (ADY1103)
//  Publica 3 métricas de negocio en CloudWatch (namespace AndysMotors/Negocio)
//
//  SEGURIDAD: este script NO contiene llaves de acceso. El cliente se crea
//  solo con la región, y el SDK toma las credenciales de la cadena por
//  defecto (CloudShell o EC2 con LabInstanceProfile).
//
//  Uso (en CloudShell):
//    node metricas-negocio.js                      -> modo normal: 1 llamada por minuto, 20 minutos
//    MODO=descontrolado node metricas-negocio.js   -> desvío controlado: sin batching, cada 1 segundo
// =====================================================================

const { CloudWatchClient, PutMetricDataCommand } = require("@aws-sdk/client-cloudwatch");

// Cliente sin credenciales escritas: solo la región
const client = new CloudWatchClient({ region: "us-east-1" });

const NAMESPACE = "AndysMotors/Negocio";
const MODO = process.env.MODO || "normal";
const INTERVALO_SEG = Number(process.env.INTERVALO_SEG || (MODO === "descontrolado" ? 1 : 60));
const DURACION_MIN = Number(process.env.DURACION_MIN || (MODO === "descontrolado" ? 10 : 20));

// Valor aleatorio entero entre min y max (simula la actividad de un minuto)
const azar = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

// Las 3 métricas de negocio. Una sola dimensión, Plataforma, con 3 valores
// posibles (agenda, crm, pagos): baja cardinalidad = solo 3 series pagadas.
function generarMetricas() {
  const ahora = new Date();
  return [
    {
      MetricName: "AgendamientosRegistrados",
      Dimensions: [{ Name: "Plataforma", Value: "agenda" }],
      Unit: "Count",
      Value: azar(25, 40),        // ~33 por minuto en horario comercial (dato EP3)
      Timestamp: ahora,
    },
    {
      MetricName: "OportunidadesCreadas",
      Dimensions: [{ Name: "Plataforma", Value: "crm" }],
      Unit: "Count",
      Value: azar(10, 20),
      Timestamp: ahora,
    },
    {
      MetricName: "PagosProcesados",
      Dimensions: [{ Name: "Plataforma", Value: "pagos" }],
      Unit: "Count",
      Value: azar(25, 40),
      Timestamp: ahora,
    },
  ];
}

// Envía una lista de métricas en UNA llamada PutMetricData
async function enviar(metricas) {
  const respuesta = await client.send(
    new PutMetricDataCommand({ Namespace: NAMESPACE, MetricData: metricas })
  );
  return respuesta.$metadata.httpStatusCode;
}

async function ciclo(n) {
  const metricas = generarMetricas();
  const hora = new Date().toLocaleTimeString("es-CL", { timeZone: "America/Santiago" });
  try {
    if (MODO === "descontrolado") {
      // SIN batching: una llamada por métrica (como el Escenario A)
      for (const m of metricas) await enviar([m]);
      console.log(`[${hora}] #${n} DESVÍO: ${metricas.length} llamadas (1 métrica c/u)`);
    } else {
      // CON batching: las 3 métricas en una sola llamada
      const status = await enviar(metricas);
      const resumen = metricas.map((m) => `${m.MetricName}=${m.Value}`).join(", ");
      console.log(`[${hora}] #${n} HTTP ${status} · 1 llamada · ${resumen}`);
    }
  } catch (err) {
    console.error(`[${hora}] #${n} ERROR: ${err.name} - ${err.message}`);
  }
}

async function main() {
  const total = Math.ceil((DURACION_MIN * 60) / INTERVALO_SEG);
  console.log(`Namespace ${NAMESPACE} · modo ${MODO} · cada ${INTERVALO_SEG} s · ${DURACION_MIN} min (${total} ciclos)`);
  for (let n = 1; n <= total; n++) {
    await ciclo(n);
    if (n < total) await new Promise((r) => setTimeout(r, INTERVALO_SEG * 1000));
  }
  console.log("Simulación terminada.");
}

main();