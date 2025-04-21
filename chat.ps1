param (
    [string]$serverPath = "./server",
    [string]$listName = "server-list.csv"
)

# Import necessary assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-FormObject {
    param (
        [String]$FormType,
        [PSCustomObject]$Attributes = [PSCustomObject]@{},
        [System.Collections.ArrayList]$Children = @()
    )

    # Create an instance of the specified form type
    $formObject = New-Object $FormType -Property $Attributes

    # Add child elements to the form object
    foreach ($child in $Children) {
        $formObject.Controls.Add($child)
    }

    return $formObject
}

# Check if the server path exists
if (-Not (Test-Path -Path $serverPath)) {
    Write-Host "Server path does not exist. Creating directory..."
    New-Item -ItemType Directory -Path $serverPath
}

$listPath = Join-Path -Path $serverPath -ChildPath $listName

# Check if the list file exists
if (-Not (Test-Path -Path $listPath)) {
    Write-Host "List file does not exist. Creating file..."
    # Create a CSV file with headers
    '"display-name","file-name","occupancy"' | Out-File -FilePath $listPath -Encoding UTF8
}

# Create a new Windows Form
$listView = New-FormObject -FormType "System.Windows.Forms.ListView" -Attributes @{
    View          = [System.Windows.Forms.View]::Details
    FullRowSelect = $true
    Dock          = [System.Windows.Forms.DockStyle]::Top
    Height        = 200
}
$listView.Columns.Add("Display Name", 150)
$listView.Columns.Add("Occupancy", 100)

$addButton = New-FormObject -FormType "System.Windows.Forms.Button" -Attributes @{
    Text     = "+"
    Location = New-Object System.Drawing.Point(10, 220)
    Size     = New-Object System.Drawing.Size(50, 30)
}

$removeButton = New-FormObject -FormType "System.Windows.Forms.Button" -Attributes @{
    Text     = "-"
    Location = New-Object System.Drawing.Point(70, 220)
    Size     = New-Object System.Drawing.Size(50, 30)
}

$form = New-FormObject -FormType "System.Windows.Forms.Form" -Attributes @{
    Text = "Server Manager"
    Size = New-Object System.Drawing.Size(400, 300)
} -Children @($listView, $addButton, $removeButton)

# Get the list of servers
function Get-Servers {
    $servers = Import-Csv -Path $listPath
    return $servers
}

# Populate the ListView with server data
function Update-ListView {
    $listView.Items.Clear()
    Get-Servers | ForEach-Object {
        $item = New-Object System.Windows.Forms.ListViewItem $_.'display-name'
        $item.SubItems.Add($_.'occupancy')
        $listView.Items.Add($item)
    }
}
Update-ListView

# Add server functionality
$addButton.Add_Click({
        $nameLabel = New-FormObject -FormType System.Windows.Forms.Label -Attributes @{
            Text     = "Display Name:"
            Location = New-Object System.Drawing.Point(10, 20)
        }

        $nameTextBox = New-FormObject -FormType System.Windows.Forms.TextBox -Attributes @{
            Location = New-Object System.Drawing.Point(120, 20)
        }

        $okButton = New-FormObject -FormType "System.Windows.Forms.Button" -Attributes @{
            Text     = "OK"
            Location = New-Object System.Drawing.Point(50, 100)
        }

        $cancelButton = New-FormObject -FormType "System.Windows.Forms.Button" -Attributes @{
            Text     = "Cancel"
            Location = New-Object System.Drawing.Point(150, 100)
        }

        $inputForm = New-FormObject -FormType "System.Windows.Forms.Form" -Attributes @{
            Text = "Add Server"
            Size = New-Object System.Drawing.Size(300, 200)
        } -Children @($nameLabel, $nameTextBox, $okButton, $cancelButton)

        $okButton.Add_Click({
                if ($nameTextBox.Text.Trim()) {
                    $newServer = [PSCustomObject]@{
                        'display-name' = $nameTextBox.Text.Trim()
                        'file-name'    = [guid]::NewGuid().ToString()
                        'occupancy'    = 0
                    }

                    $servers = @()
                    Get-Servers | ForEach-Object {
                        $servers += $_
                    }
                    $servers += $newServer
                    $servers | Export-Csv -Path $listPath -NoTypeInformation -Encoding UTF8

                    Update-ListView
                    $inputForm.Close()
                }
            })

        $cancelButton.Add_Click({ $inputForm.Close() })

        $inputForm.ShowDialog()
    })

# Remove server functionality
$removeButton.Add_Click({
        if ($listView.SelectedItems.Count -gt 0) {
            $selectedItem = $listView.SelectedItems[0]
            $servers = Get-Servers | Where-Object { $_.'display-name' -ne $selectedItem.Text }
            $servers | Export-Csv -Path $listPath -NoTypeInformation -Encoding UTF8
            Update-ListView
        }
    })

# Show the form
[void]$form.ShowDialog()