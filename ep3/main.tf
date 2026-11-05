terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Correo que recibirá las alertas (se define en terraform.tfvars, que no se sube a GitHub)
variable "email_alertas" {
  type = string
}

locals {
  log_group = "/andysmotors/plataformas" # lo creó el CloudWatch Agent
  namespace = "AndysMotors"
}

# ---------- Filtros métricos: convierten eventos de log en métricas ----------

resource "aws_cloudwatch_log_metric_filter" "agendamientos_descartados" {
  name           = "AgendamientosDescartados"
  log_group_name = local.log_group
  pattern        = "{ $.mensaje = \"agendamiento descartado sin persistir\" }"

  metric_transformation {
    name          = "AgendamientosDescartados"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "oportunidades_sin_cliente" {
  name           = "OportunidadesSinCliente"
  log_group_name = local.log_group
  pattern        = "{ $.mensaje = \"oportunidad creada sin cliente asociado\" }"

  metric_transformation {
    name          = "OportunidadesSinCliente"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "pagos_lentos" {
  name           = "PagosLentos"
  log_group_name = local.log_group
  pattern        = "{ $.servicio = \"pagos\" && $.duracion_ms > 3000 }"

  metric_transformation {
    name          = "PagosLentos"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "errores_aplicacion" {
  name           = "ErroresAplicacion"
  log_group_name = local.log_group
  pattern        = "{ $.nivel = \"error\" }"

  metric_transformation {
    name          = "ErroresAplicacion"
    namespace     = local.namespace
    value         = "1"
    default_value = "0"
  }
}

# ---------- SNS: tópico y suscripción por correo ----------

resource "aws_sns_topic" "alertas" {
  name = "andysmotors-alertas"
}

resource "aws_sns_topic_subscription" "correo" {
  topic_arn = aws_sns_topic.alertas.arn
  protocol  = "email"
  endpoint  = var.email_alertas
}

# ---------- Alarma: 1 agendamiento perdido en 5 minutos ----------

resource "aws_cloudwatch_metric_alarm" "agenda_silenciosa" {
  alarm_name          = "AndysMotors-Agenda-Silenciosa"
  alarm_description   = "Agendamientos que el cliente cree registrados y no existen"
  namespace           = local.namespace
  metric_name         = "AgendamientosDescartados"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alertas.arn]
  ok_actions          = [aws_sns_topic.alertas.arn]
}
