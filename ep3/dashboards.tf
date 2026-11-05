# La EC2 de la EP2, buscada por su nombre
data "aws_instance" "ep2" {
  filter {
    name   = "tag:Name"
    values = ["AndysMotors-EP2"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

locals {
  id  = data.aws_instance.ep2.id
  src = "SOURCE '/andysmotors/plataformas'"
  reg = "us-east-1"
}

# ---------------- Dashboard 1: Infraestructura ----------------
resource "aws_cloudwatch_dashboard" "infraestructura" {
  dashboard_name = "AndysMotors-Infraestructura"
  dashboard_body = jsonencode({
    widgets = [
      { type = "text", x = 0, y = 0, width = 24, height = 2, properties = {
      markdown = "## AndysMotors · Infraestructura\nServidor que aloja las 6 plataformas (EC2 AndysMotors-EP2). ¿Tiene recursos suficientes?" } },

      { type = "metric", x = 0, y = 2, width = 12, height = 6, properties = {
        title   = "CPU de la instancia (%)", region = local.reg, view = "timeSeries", stat = "Average", period = 60,
        metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", local.id]],
      yAxis = { left = { min = 0, max = 100 } } } },

      { type = "metric", x = 12, y = 2, width = 12, height = 6, properties = {
        title   = "Memoria usada (%) · CloudWatch Agent", region = local.reg, view = "timeSeries", period = 60,
        metrics = [[{ expression = "SEARCH('Namespace=\"CWAgent\" MetricName=\"mem_used_percent\"', 'Average', 60)", label = "Memoria", id = "m" }]],
      yAxis = { left = { min = 0, max = 100 } } } },

      { type = "metric", x = 0, y = 8, width = 12, height = 6, properties = {
        title = "Disco usado (%) · CloudWatch Agent", region = local.reg, view = "singleValue", period = 300,
      metrics = [[{ expression = "SEARCH('Namespace=\"CWAgent\" MetricName=\"disk_used_percent\"', 'Average', 300)", label = "Disco /", id = "d" }]] } },

      { type = "metric", x = 12, y = 8, width = 12, height = 6, properties = {
        title = "Tráfico de red (bytes)", region = local.reg, view = "timeSeries", stat = "Sum", period = 300,
      metrics = [["AWS/EC2", "NetworkIn", "InstanceId", local.id], ["AWS/EC2", "NetworkOut", "InstanceId", local.id]] } },

      { type = "metric", x = 0, y = 14, width = 24, height = 4, properties = {
        title = "Estado de la instancia (0 = OK)", region = local.reg, view = "singleValue", stat = "Maximum", period = 300,
      metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", local.id]] } }
    ]
  })
}

# ---------------- Dashboard 2: Negocio ----------------
resource "aws_cloudwatch_dashboard" "negocio" {
  dashboard_name = "AndysMotors-Negocio"
  dashboard_body = jsonencode({
    widgets = [
      { type = "metric", x = 0, y = 0, width = 16, height = 6, properties = {
        title = "Fallas detectadas en los logs (cada 5 min)", region = local.reg, view = "timeSeries", stat = "Sum", period = 300,
        metrics = [
          ["AndysMotors", "AgendamientosDescartados", { label = "Agendamientos descartados" }],
          ["AndysMotors", "OportunidadesSinCliente", { label = "Oportunidades sin cliente" }],
          ["AndysMotors", "PagosLentos", { label = "Pagos lentos (> 3 s)" }],
          ["AndysMotors", "ErroresAplicacion", { label = "Errores de aplicación" }]
      ] } },

      { type = "alarm", x = 16, y = 0, width = 8, height = 6, properties = {
      title = "Estado de la alarma", alarms = [aws_cloudwatch_metric_alarm.agenda_silenciosa.arn] } },

      { type = "log", x = 0, y = 6, width = 24, height = 7, properties = {
        title = "Latencia p95 por plataforma (ms) · Logs Insights", region = local.reg, view = "timeSeries",
      query = "${local.src} | filter mensaje = \"peticion atendida\" | stats pct(duracion_ms, 95) as p95_ms by bin(5m), servicio" } },

      { type = "log", x = 0, y = 13, width = 10, height = 7, properties = {
        title = "Agendamientos perdidos por sucursal · Logs Insights", region = local.reg, view = "bar",
      query = "${local.src} | filter mensaje = \"agendamiento descartado sin persistir\" | stats count(*) as perdidos by sucursal" } },

      { type = "log", x = 10, y = 13, width = 14, height = 7, properties = {
        title = "Últimos eventos críticos · Logs Insights", region = local.reg, view = "table",
      query = "${local.src} | fields @timestamp, servicio, nivel, mensaje | filter nivel in [\"warn\", \"error\"] and mensaje != \"escenario de falla modificado\" | sort @timestamp desc | limit 20" } },

      { type = "text", x = 0, y = 20, width = 24, height = 3, properties = {
      markdown = "### Runbook · si la alarma se activa\n1. Revisar *Agendamientos perdidos por sucursal* y avisar a esas sucursales.\n2. Buscar el `request_id` en Logs Insights para seguir la transacción.\n3. Escalar al equipo de agenda si persiste más de 10 minutos." } }
    ]
  })
}
