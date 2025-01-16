function Get-WorkerRoutes {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        [Parameter(Mandatory)]
        [string]$zoneID
    )
    
    try {
        $uri = "https://api.cloudflare.com/client/v4/zones/$zoneID/workers/routes"
        $workerRoutes = Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers
        
        return $workerRoutes.result.Count -gt 0 ? $workerRoutes.result : $null
    }
    catch {
        Write-Error $_.Exception.Message
        throw
    }
}

function Set-WorkerRouteStatus {
    param (
        [Parameter(Mandatory)]
        [PsCustomObject]$workerRoute,
        [Parameter(Mandatory)]
        [hashtable]$headers,
        [Parameter(Mandatory)]
        [string]$zoneId,
        [Parameter()]
        [object]$workerScriptName
    )
    
    try {
        $ApiBody = @{
            id      = $workerRoute.Id
            pattern = $workerRoute.Pattern
            script  = $workerScriptName
        } | ConvertTo-Json

        $uri = "https://api.cloudflare.com/client/v4/zones/$zoneId/workers/routes/$($workerRoute.Id)"
        
        $result = Invoke-RestMethod -Uri $uri `
            -Headers $headers `
            -Body $ApiBody `
            -Method Put `
            -ContentType 'application/json'

        Write-Host "Set script '$workerScriptName' on worker route '$($workerRoute.Pattern)'"
        
        # Verify the update
        $CheckRoute = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        if ($CheckRoute.result.script -ne $workerScriptName) {
            $errorMessage = if ($null -eq $workerScriptName) {
                "Failed to disable CloudFlareRoute '$($workerRoute.Id)' with pattern '$($workerRoute.Pattern)'"
            } else {
                "Failed to update CloudFlareRoute '$($workerRoute.Id)' with pattern '$($workerRoute.Pattern)' and route '$workerScriptName'"
            }
            throw $errorMessage
        }
    }
    catch {
        Write-Error "Error updating $($workerRoute.pattern): $_"
        throw
    }
}

# Configuration
$config = @{
    CfApiKey = "xxxx123123"  # Better to use environment variable or secure string
    CfZoneId = "zoneID123zoneID123zoneID123zoneID123zoneID123"
    RoutePattern = "resdevops.com/*"
    WorkerScriptName = "some-worker-name"
}

try {
    $apiRequestHeaders = @{
        'Authorization' = "Bearer $($config.CfApiKey)"
        'Content-Type' = 'application/json'
    }

    $allWorkerRoutes = Get-WorkerRoutes -Headers $apiRequestHeaders -zoneID $config.CfZoneId
    
    if (-not $allWorkerRoutes) {
        throw "No worker routes returned for zoneID $($config.CfZoneId)"
    }

    $allRoutePatterns = $config.RoutePattern -split ","
    
    foreach ($routePattern in $allRoutePatterns) {
        $filteredWorkerRoutes = $allWorkerRoutes.Where({ $_.Pattern -eq $routePattern })
        
        foreach ($route in $filteredWorkerRoutes) {
            Write-Host "Processing $route"
            switch ($config.routeAction.ToLower()) {
                'enable' { 
                    Set-WorkerRouteStatus -workerRoute $route -headers $apiRequestHeaders -zoneId $config.CfZoneId -workerScriptName $config.WorkerScriptName 
                }
                'disable' { 
                    Set-WorkerRouteStatus -workerRoute $route -headers $apiRequestHeaders -zoneId $config.CfZoneId -workerScriptName $null 
                }
                'status' { 
                    Write-Host "Route: $($route.pattern), Script value: $($route.script)" 
                }
                default { 
                    throw "Invalid maintenance routeAction. Use: enable/disable/status" 
                }
            }
        }
    }
    
    Write-Host "Maintenance-mode task complete."
}
catch {
    Write-Error $_
    exit 1
}
