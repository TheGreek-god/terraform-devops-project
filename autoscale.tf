# create autoscale resource that will decrease the number of instances if the azurerm_orchestrated_scale set cpu usaae is below 10% for 2 minutes
resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale"
  location            = data.azurerm_resource_group.greekrg.location
  resource_group_name = data.azurerm_resource_group.greekrg.name
  target_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
  enabled             = true

  profile {
    name = "autoscale"

    capacity {
      default = 3
      minimum = 1
      maximum = 10
    }

    /* ---------- SCALE‑OUT  (> 80 % CPU, 2 min) ---------- */
    rule {
      metric_trigger {
        metric_name         = "Percentage CPU"
        metric_namespace    = "Microsoft.Compute/virtualMachineScaleSets"
        metric_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain          = "PT1M"
        statistic           = "Average"
        time_window         = "PT2M"
        time_aggregation    = "Average"
        operator            = "GreaterThan"
        threshold           = 80
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    /* ---------- SCALE‑IN  (< 10 % CPU, 2 min) ---------- */
    rule {
      metric_trigger {
        metric_name         = "Percentage CPU"
        metric_namespace    = "Microsoft.Compute/virtualMachineScaleSets"
        metric_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain          = "PT1M"
        statistic           = "Average"
        time_window         = "PT2M"
        time_aggregation    = "Average"
        operator            = "LessThan"
        threshold           = 10
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
