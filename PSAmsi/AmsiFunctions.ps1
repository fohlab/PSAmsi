﻿If ((gci env: | ? { $_.Name -eq 'OS' }).Value -eq 'Windows_NT' -AND
(Get-CimInstance Win32_OperatingSystem).Version.StartsWith('10')) {
    # Create an InMemoryModule, AMSINativeMethods, and AMSI_Result enum. (Uses PSReflect written by Matt Graeber (@mattifestation))
    $Module = New-InMemoryModule -ModuleName AMSI

    $FunctionDefinitions = @(
       (func amsi AmsiInitialize ([UInt32]) @([String], [Int64].MakeByRefType()) -SetLastError),
       (func amsi AmsiUninitialize ([Void]) @([IntPtr]) -SetLastError),
       (func amsi AmsiOpenSession ([UInt32]) @([IntPtr], [Int64].MakeByRefType()) -SetLastError),
       (func amsi AmsiCloseSession ([Void]) @([IntPtr], [IntPtr]) -SetLastError),
       (func amsi AmsiScanBuffer ([UInt32]) @([IntPtr], [IntPtr], [UInt32], [String], [IntPtr], [Int32].MakeByRefType()) -SetLastError),
       (func amsi AmsiScanString ([UInt32]) @([IntPtr], [String], [String], [IntPtr], [Int32].MakeByRefType()) -SetLastError)
    )

    $AMSI_Result = psenum $Module AMSI.AMSI_RESULT UInt32 @{
       AMSI_RESULT_CLEAN = 0
       AMSI_RESULT_NOT_DETECTED = 1
       AMSI_RESULT_DETECTED = 32768
    }

    $Types = $FunctionDefinitions | Add-Win32Type -Module $Module -Namespace 'AMSI.NativeMethods'
    $AMSINativeMethods = $Types['amsi']
}

function AmsiInitialize {
    <#

    .SYNOPSIS

    Initializes an AmsiContext to conduct AMSI scans.

    Author: Ryan Cobb (@cobbr_io)
    License: GNU GPLv3
    Required Dependecies: PSReflect, AMSINativeMethods
    Optional Dependencies: none

    .DESCRIPTION

    AmsiInitialize initializes an AmsiContext to conduct AMSI scans by calling the function
    described here: https://msdn.microsoft.com/en-us/library/windows/desktop/dn889862(v=vs.85).aspx 

    .PARAMETER appName

    The name of the App that will be submitting AMSI scan requests.

    .PARAMETER amsiContext

    A reference to the amsiContext that will be set by this function.

    .OUTPUTS

    Int

    .EXAMPLE

    $AmsiContext = [IntPtr]::Zero
    AmsiInitialize -appName "PSAmsi" -amsiContext ([ref]$AmsiContext)

    .NOTES

    AmsiInitialize is a part of PSAmsi, a tool for auditing and defeating AMSI signatures.

    PSAmsi is located at https://github.com/cobbr/PSAmsi. Additional information can be found at https://cobbr.io.

    #>
    Param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $appName,

        [Parameter(Position = 1, Mandatory)]
        [ref] $amsiContext
    )

    $HResult = $AMSINativeMethods::AmsiInitialize($appName, $amsiContext)

    If ($HResult -ne 0) {
        throw "AmsiInitialize Error: $($HResult). AMSI may not be enabled on your system."
    }

    $HResult
}

function AmsiOpenSession {
    <#

    .SYNOPSIS

    Opens an AmsiSession associated with an AmsiContext to conduct AMSI scans.

    Author: Ryan Cobb (@cobbr_io)
    License: GNU GPLv3
    Required Dependecies: PSReflect, AMSINativeMethods
    Optional Dependencies: none

    .DESCRIPTION

    AmsiOpenSession opens an AmsiSession assocaited with an AmsiContext by calling the function
    described here: https://msdn.microsoft.com/en-us/library/windows/desktop/dn889863(v=vs.85).aspx 

    .PARAMETER amsiContext

    A pointer to the AmsiContext for which this AmsiSession will be associated.

    .PARAMETER session

    A reference to the AmsiSession that will be set by this function.

    .OUTPUTS

    Int

    .EXAMPLE

    $AmsiSession = [IntPtr]::Zero
    AmsiInitialize -amsiContext $AmsiContext -session ([ref]$AmsiSession)

    .NOTES

    AmsiOpenSession is a part of PSAmsi, a tool for auditing and defeating AMSI signatures.

    PSAmsi is located at https://github.com/cobbr/PSAmsi. Additional information can be found at https://cobbr.io.

    #>
    Param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [IntPtr] $amsiContext,

        [Parameter(Position = 1, Mandatory)]
        [ref] $session
    )

    $HResult = $AMSINativeMethods::AmsiOpenSession($amsiContext, $session)

    If ($HResult -ne 0) {
        throw "AmsiOpenSession Error: $($HResult)"
    }

    $HResult
}

function AmsiScanString {
    <#

    .SYNOPSIS

    Submits a string to the AMSI to be scanned by the AntiMalware Provider.

    Author: Ryan Cobb (@cobbr_io)
    License: GNU GPLv3
    Required Dependecies: PSReflect, AMSINativeMethods
    Optional Dependencies: none

    .DESCRIPTION

    AmsiScanString submits a string to to the AMSI to be scanned by the AntiMalware provider by calling
    the function described here: https://msdn.microsoft.com/en-us/library/windows/desktop/dn889866(v=vs.85).aspx

    .PARAMETER amsiContext

    A pointer to the AmsiContext this scan is associated with.

    .PARAMETER string

    The string to be scanned for malware.

    .PARAMETER contentName

    The name of the content to be scanned.

    .PARAMETER session

    A pointer to the AmsiSession this scan is a part of.

    .PARAMETER result

    A reference to the result of the scan that will be set by this function.

    .OUTPUTS

    Int

    .EXAMPLE

    $AmsiResult = $AMSI_Result::AMSI_RESULT_NOT_DETECTED
    AmsiScanString $AmsiContext $ScriptString $ContentName $AmsiSession -result ([ref]$AmsiResult)

    .NOTES

    AmsiScanString is a part of PSAmsi, a tool for auditing and defeating AMSI signatures.

    PSAmsi is located at https://github.com/cobbr/PSAmsi. Additional information can be found at https://cobbr.io.

    #>
    Param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [IntPtr] $amsiContext,

        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $string,

        [Parameter(Position = 2, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $contentName,

        [Parameter(Position = 3, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [IntPtr] $session,

        [Parameter(Position = 4, Mandatory)]
        [ref] $result
    )

    $HResult = $AMSINativeMethods::AmsiScanString($amsiContext, $string, $contentName, $session, $result)

    If ($HResult -ne 0) {
        throw "AmsiScanString Error: $($HResult)"
    }

    $HResult
}

function AmsiScanBuffer {
    <#

    .SYNOPSIS

    Submits a buffer to the AMSI to be scanned by the AntiMalware Provider.

    Author: Ryan Cobb (@cobbr_io)
    License: GNU GPLv3
    Required Dependecies: PSReflect, AMSINativeMethods
    Optional Dependencies: none

    .DESCRIPTION

    AmsiScanBuffer submits a buffer to the AMSI to be scanned by the AntiMalware provider by calling the
    function described here: https://msdn.microsoft.com/en-us/library/windows/desktop/dn889865(v=vs.85).aspx

    .PARAMETER amsiContext

    A pointer to the AmsiContext this scan is associated with.

    .PARAMETER buffer

    A pointer to the buffer to be scanned for malware.

    .PARAMETER length

    The length of the buffer to be scanned for malware.

    .PARAMETER contentName

    The name of the content to be scanned.

    .PARAMETER session

    A pointer to the AmsiSession this scan is a part of.

    .PARAMETER result

    A reference to the result of the scan that will be set by this function.

    .OUTPUTS

    Int

    .EXAMPLE

    $AmsiResult = $AMSI_Result::AMSI_RESULT_NOT_DETECTED
    AmsiScanBuffer $AmsiContext $Buffer $Length $ContentName $AmsiSession -result ([ref]$AmsiResult)

    .NOTES

    AmsiScanBuffer is a part of PSAmsi, a tool for auditing and defeating AMSI signatures.

    PSAmsi is located at https://github.com/cobbr/PSAmsi. Additional information can be found at https://cobbr.io.

    #>
    Param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [IntPtr] $amsiContext,

        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [IntPtr] $buffer,

        [Parameter(Position = 2, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Int] $length,

        [Parameter(Position = 3, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $contentName,

        [Parameter(Position = 4, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [IntPtr] $session,

        [Parameter(Position = 5, Mandatory)]
        [ref] $result
    )

    $HResult = $AMSINativeMethods::AmsiScanString($amsiContext, $buffer, $length, $contentName, $session, $result)

    If ($HResult -ne 0) {
        throw "AmsiScanBuffer Error: $($HResult)"
    }

    $HResult
}

function AmsiResultIsMalware {
    <#

    .SYNOPSIS

    Determines if a previous AmsiScan detected malware, based on it's AmsiResult.

    Author: Ryan Cobb (@cobbr_io)
    License: GNU GPLv3
    Required Dependecies: PSReflect, AMSI_Result
    Optional Dependencies: none

    .DESCRIPTION

    AmsiResultIsMalware takes the result from an AmsiScanString or AmsiScanBuffer scan and 
    uses the AMSI_Result enum to determine if the scan detected malware.

    .PARAMETER AMSIRESULT

    The result from a AmsiScanString or AmsiScanBuffer call.

    .OUTPUTS

    Bool

    .EXAMPLE

    $AmsiResult = $AMSI_Result::AMSI_RESULT_NOT_DETECTED
    AmsiScanString $Context $Content $ContentName $Session -result ([ref]$AmsiResult)
    AmsiResultIsMalware -AMSIRESULT $AmsiResult

    .NOTES

    AmsiResultIsMalware is a part of PSAmsi, a tool for auditing and defeating AMSI signatures.

    PSAmsi is located at https://github.com/cobbr/PSAmsi. Additional information can be found at https://cobbr.io.

    #>
    Param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateSet(0, 1, 16384, 20479, 32768)]
        [UInt32] $AMSIRESULT
    )

    If(($AMSIRESULT -ne $AMSI_Result::AMSI_RESULT_CLEAN) -and
    ($AMSIRESULT -ne $AMSI_Result::AMSI_RESULT_NOT_DETECTED)) {
        $True
    }
    Else { $False }
}

function AmsiCloseSession {
    <#

    .SYNOPSIS

    Closes an AmsiSession opened with AmsiOpenSession.

    Author: Ryan Cobb (@cobbr_io)
    License: GNU GPLv3
    Required Dependecies: PSReflect, AMSINativeMethods
    Optional Dependencies: none

    .DESCRIPTION

    AmsiCloseSession closes an AmsiSession opened with AmsiOpenSession by calling the function
    described here: https://msdn.microsoft.com/en-us/library/windows/desktop/dn889861(v=vs.85).aspx

    .PARAMETER amsiContext

    A pointer to the AmsiContext for which this AmsiSession is associated.

    .PARAMETER session

    A pointer to the AmsiSession to be closed.

    .OUTPUTS

    None

    .EXAMPLE

    $AmsiSession = [IntPtr]::Zero
    AmsiOpenSession -amsiContext $AmsiContext -session ([ref]$AmsiSession)
    AmsiCloseSession -amsiConext $AmsiContext -session $AmsiSession

    .NOTES

    AmsiCloseSession is a part of PSAmsi, a tool for auditing and defeating AMSI signatures.

    PSAmsi is located at https://github.com/cobbr/PSAmsi. Additional information can be found at https://cobbr.io.

    #>
    Param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [IntPtr] $amsiContext,

        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [IntPtr] $session
    )

    $HResult = $AMSINativeMethods::AmsiCloseSession($amsiContext, $session)
}

function AmsiUninitialize {
    <#

    .SYNOPSIS

    Uninitializes an AmsiContext initialized with AmsiInitialize.

    Author: Ryan Cobb (@cobbr_io)
    License: GNU GPLv3
    Required Dependecies: PSReflect, AMSINativeMethods
    Optional Dependencies: none

    .DESCRIPTION

    AmsiUninitialize uninitializes an AmsiContext initialized with AmsiInitialize by calling the function
    described here: https://msdn.microsoft.com/en-us/library/windows/desktop/dn889867(v=vs.85).aspx

    .PARAMETER amsiContext

    A pointer to the AmsiContext to be uninitialized.

    .OUTPUTS

    None

    .EXAMPLE

    $AmsiContext = [IntPtr]::Zero
    AmsiInitialize -appName "PSAmsi" -amsiContext ([ref]$AmsiContext)
    AmsiUninitialize -amsiConext $AmsiContext

    .NOTES

    AmsiUninitialize is a part of PSAmsi, a tool for auditing and defeating AMSI signatures.

    PSAmsi is located at https://github.com/cobbr/PSAmsi. Additional information can be found at https://cobbr.io.

    #>
    Param (
        [Parameter(Position = 0, Mandatory)]
        [IntPtr] $amsiContext
    )

    $HResult = $AMSINativeMethods::AmsiUninitialize($amsiContext)
}
