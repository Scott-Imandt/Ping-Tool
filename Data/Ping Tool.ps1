Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted

$currentDirectory = Get-Location
Write-Host $currentDirectory
$xamlPath = Join-Path $currentDirectory "\MainWindow.xaml"
#$xamlPath = "U:\Support\IT Support Tools\Ping Tool\Data\MainWindow.xaml"
$inputXAML=Get-Content -Path $xamlPath -Raw
$inputXAML=$inputXAML -replace 'mc:Ignorable="d"','' -replace "x:N","N" -replace '^<Win.*','<Window'
[XML]$XAML=$inputXAML

$reader = New-Object System.Xml.XmlNodeReader $XAML
try{
    $form1=[Windows.Markup.XamlReader]::Load($reader)
}catch{
    Write-Host $_.Exception
    throw
}

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    try{
        Set-Variable -Name "var_$($_.Name)" -Value $form1.FindName($_.Name) -ErrorAction Stop
    }catch{
        throw
    }
}

#$form1.Icon = "U:\Support\IT Support Tools\Ping Tool\Data\icon-1024x1024.ico"

$ping = New-Object System.Net.NetworkInformation.Ping
$pingOptions = New-Object System.Net.NetworkInformation.PingOptions
$pingOptions.Ttl = 64  # Optional: Adjust the TTL (Time To Live) if needed
$timeout = 200  # Set the timeout in milliseconds (200ms in this case)


$ColumnsIP=@(
    'Address'
    'Status'
    'Mac Address'
    'State'
    'Name'
)


$var_DataGrid_IP.FontSize= '18'

$IPDataTable=New-Object System.Data.DataTable
[void]$IPDataTable.Columns.AddRange($ColumnsIP)

$var_Label_IP.Visibility = "Hidden"
$var_Label_DNS_Status.Visibility = "Hidden"
$var_Label_Buffer_Status.Visibility = "Hidden"
$var_Label_MAC_Status.Visibility = "Hidden"
$var_Label_Status.Visibility= "Hidden"
$var_Label_RTT_Status.Visibility= "Hidden"
$var_Label_MAC_State_Status.Visibility= "Hidden"


function Add-PingResultToDataGrid($address, $status, $mac, $state, $name){

    $row = $IPDataTable.NewRow()
    $row['Address'] = $address
    $row['Status'] = $status
    $row['Mac Address'] = $mac
    $row['State'] = $state
    $row['name'] = $name
    $IPDataTable.Rows.Add($row)
}


# Function to convert an IP address into its octet components
function Convert-IPToOctets($ipAddress) {
    return $ipAddress.Split('.') | ForEach-Object { [int]$_ }
}

# Function to convert octets back to an IP address string
function Convert-OctetsToIP($octets) {
    return "$($octets[0]).$($octets[1]).$($octets[2]).$($octets[3])"
}



# Function to loop through the range of IP addresses and ping each one
function Ping-IPRange($startIP, $endIP) {
    
    # Define the regex for validating IPv4 address format
    $ipRegex = '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

    if($startIP -notmatch $ipRegex -and $endIP -notmatch $ipRegex -or $endIP -eq $null){
        Write-Host "ERROR: Ip is not in the correct format"
        return
    }
    
    
    $startOctets = Convert-IPToOctets $startIP
    $endOctets = Convert-IPToOctets $endIP
    
    #if Only One IP Address is entered
    if($startOctets -ne 0 -and $endOctets -eq 0){
        $endOctets = $startOctets.Clone()
        $endOctets[3] = $startOctets[3]+1
    }

    
    # Exception handling to prevent incorrect similar ip addresses
    if($startOctets[0] -ne $endOctets[0] -or $startOctets[1] -ne $endOctets[1] -or $startOctets[2] -ne $endOctets[2]){
        Write-Host "ERROR: IP address need to match except the last digit"
        return 
    }

    # Exception to handle incorrect order or ips
    if($startOctets[3] -gt $endOctets[3]){
        Write-Host "Error: IP addresses are not in accending order"
        return
    }


    # Calculate the difference between the last octet
    $diff = $endOctets[3] - $startOctets[3]

    if($diff -gt 15){
        # Loop through the range (assuming the range is just the last octet for simplicity)
        for ($i = $startOctets[3]; $i -le $endOctets[3]; $i++) {
            $currentIP = "$($startOctets[0]).$($startOctets[1]).$($startOctets[2]).$i"
            $reply = $ping.Send($currentIP, $timeout)
            if($reply.Status -eq "Success"){
                $neighbor = Get-NetNeighbor -AddressFamily IPv4 |
                    Where-Object {
                        $_.IPAddress -eq $currentIP -and
                        $_.LinkLayerAddress -ne '00-00-00-00-00-00'
                    }

                # Then extract the MAC and state if available
                $mac = if ($neighbor) { $neighbor.LinkLayerAddress } else { "" }
                $state = if ($neighbor) { $neighbor.State } else { "" }  
            }
            else{
                $mac = ""
                $state = ""
            }

            Add-PingResultToDataGrid $currentIP $reply.Status $mac $state
        }
    }
    else{
        # Loop through the range (assuming the range is just the last octet for simplicity)
        for ($i = $startOctets[3]; $i -lt $endOctets[3]; $i++) {
            $currentIP = "$($startOctets[0]).$($startOctets[1]).$($startOctets[2]).$i"
            $reply = $ping.Send($currentIP)
            if($reply.Status -eq "Success"){
                $neighbor = Get-NetNeighbor -AddressFamily IPv4 |
                    Where-Object {
                        $_.IPAddress -eq $currentIP -and
                        $_.LinkLayerAddress -ne '00-00-00-00-00-00'
                    }

                # Then extract the MAC and state if available
                $mac = if ($neighbor) { $neighbor.LinkLayerAddress } else { "" }
                $state = if ($neighbor) { $neighbor.State } else { "" }  
                try {
                    $name = Resolve-DnsName -Name $currentIP -ErrorAction Stop |
                    Select-Object -ExpandProperty NameHost
                } catch {
                    $name =""
                }
            }
            else{
                $mac = ""
                $state = ""
                $name = ""
            }
            
            Add-PingResultToDataGrid $currentIP $reply.Status $mac $state $name
    }
    }
    
    

    # Bind the DataGrid to the updated DataTable
    $var_DataGrid_IP.ItemsSource = $IPDataTable.DefaultView

}

# Event handler for when a row is clicked in the DataGrid
$var_DataGrid_IP.Add_MouseLeftButtonUp({
    $selectedItem = $var_DataGrid_IP.SelectedItem

    if ($selectedItem) {
        # Action to take when a row is clicked
        $ip = $selectedItem['Address']
        
        $reply = $ping.Send($ip)

        $var_Label_IP.Content = $ip
        $var_Label_Status.Content = $reply.Status
        if($reply.Status -eq "Success"){
                $neighbor = Get-NetNeighbor -AddressFamily IPv4 |
                    Where-Object {
                        $_.IPAddress -eq $ip -and
                        $_.LinkLayerAddress -ne '00-00-00-00-00-00'
                    }

                # Then extract the MAC and state if available
                $var_Label_MAC_Status.Content = if ($neighbor) { $neighbor.LinkLayerAddress } else { '00-00-00-00-00-00' }
                $var_Label_MAC_State_Status.Content = if ($neighbor) { $neighbor.State } else { "UNKNOWN" }  
                try {
                    $DNSNAME = Resolve-DnsName -Name $ip -ErrorAction Stop |
                    Select-Object -ExpandProperty NameHost

                    $var_Label_DNS_Status.Content = if($DNSNAME) {$DNSName.ToString()} else {'N/A'}
                } catch {
                    $var_Label_DNS_Status.Content =""
                }
        }
        else{
                $var_Label_MAC_Status.Content = ""
                $var_Label_MAC_State_Status.Content = ""
                $var_Label_DNS_Status.Content = ""
            }

        $var_Label_Buffer_Status.Content = $reply.Buffer.Length
        $var_Label_RTT_Status.Content = $reply.RoundtripTime.ToString() + " ms"

        $var_Label_IP.Visibility = "Visible"
        $var_Label_Status.Visibility= "Visible"
        $var_Label_DNS_Status.Visibility = "Visible"
        $var_Label_Buffer_Status.Visibility = "Visible"
        $var_Label_MAC_Status.Visibility = "Visible"
        $var_Label_RTT_Status.Visibility= "Visible"
        $var_Label_MAC_State_Status.Visibility= "Visible"
        
    }
})


$var_Button_Submit.Add_Click({

    $var_DataGrid_IP.Clear()
    $IPDataTable.Rows.Clear()
    $var_Label_IP.Visibility = "Hidden"
    $var_Label_Status.Visibility= "Hidden"
    $var_Label_DNS_Status.Visibility = "Hidden"
    $var_Label_Buffer_Status.Visibility = "Hidden"
    $var_Label_MAC_Status.Visibility = "Hidden"
    $var_Label_RTT_Status.Visibility= "Hidden"
    $var_Label_MAC_State_Status.Visibility= "Hidden"

    $startIP = $var_IPStart.Text
    $endIP = $var_IPEnd.Text

    # Ping the range of IP addresses
    Ping-IPRange $startIP $endIP    

})

$var_Button_Help.Add_Click({

$help = "PING TOOL V2.0.0`n`n`n-SINGLE PING:  Type in one IP Address in start textbox, then click 'Submit' to ping only one address`n`n-RANGE PING: Type in a range of IP's from start to end to ping multiple IP's in that range`n`n-RANGE PING(Functioality):  If number of IP's to ping is greater the 15 then ping type changes to timeout mode (200ms) to reduce loadtime of application`n`n-Any IP can be ping to completion by clicking it inside the datatable`n`n-Only a range of the final ip value can be iterated on`n`n-MAC ADDRESS: MAC Addresses are only avalible if the computer preforming the ping is connected to the same subnet as the target device (Ping computer is the same physical location as target (C.I, CCB, Court Street))`n`n-DNS Name: If device DNS record has been created then DNS name will appear when clicking on it in table(Device name not guarenteed to appear)
`n`n`n-MAC STATES`n`n--REACHABLE: ✅ MAC address is known and recently confirmed alive`n--STALE: 😐MAC is known, but not recently confirmed — may need to be re-verified`n--DELAY: ⏳Waiting before re-sending ARP/NDP to confirm reachability`n--PROBE: 🔍Actively probing (re-sending ARP/NDP to confirm device is alive)`n--UNREACHABLE: ❌MAC address could not be resolved / host is down`n--PERMANENT: 📌Entry is static (manually added), doesn’t expire`n--INCOMPLETE: 🛑 ARP/NDP resolution is in progress, but MAC isn’t known yet"



[System.Windows.Forms.MessageBox]::Show($help)


})




# Show the form
$form1.ShowDialog()





