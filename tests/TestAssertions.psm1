function HaveProperty($ActualValue, [string]$PropertyName, [switch] $Negate, [string] $Because) {

    $hasProperty = $null -ne ($ActualValue.PSObject.Properties | Where-Object Name -eq $PropertyName)

    if ($Negate) {
        $hasProperty = -not $hasProperty
        $failureMessage = "Expected object to not have property '$PropertyName', but it does."
    } else {
        $failureMessage = "Expected object to have property '$PropertyName', but it does not."
    }

    return @{
        Succeeded = $hasProperty
        FailureMessage = $failureMessage
    }
}

# Register the custom assertion with Pester
Add-ShouldOperator -Name HaveProperty -InternalName HaveProperty -Test ${function:HaveProperty}
