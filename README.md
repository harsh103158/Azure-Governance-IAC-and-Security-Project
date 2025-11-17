# Azure Governance, IAC and Security Project

## 🎯 Project Summary

This project demonstrates the deployment of a resilient, scalable Windows web application infrastructure on Azure, specifically focusing on integrating best practices for **Infrastructure as Code (IaC)**, enforcing **Azure Governance Policies**, and implementing the **Principle of Least Privilege (RBAC)**.

The deployment targets a production environment (`RG-Prod`) and features a high-availability Virtual Machine Scale Set (VMSS) running IIS behind a Standard Load Balancer.

---

## 🏗️ Architecture and Components

The core infrastructure is defined in `VNet-LB-VMSS-Storage.json` and `deploystorage.json` includes the following resources:

| Resource | ARM Name | Purpose |
| :--- | :--- | :--- |
| **Virtual Network** | `vnet-iac-prod` | Primary network for all resources (10.0.0.0/16). |
| **Load Balancer** | `lb-vmss-public` | Standard SKU Load Balancer for public traffic distribution. |
| **Compute** | `webVMSS` | Virtual Machine Scale Set (2 instances) running **Windows Server 2025**. |
| **Web Service** | Custom Script Extension | Installs IIS and configures a dynamic welcome page via `install-iis.ps1`. |
| **Storage** | Deployed Separately | Policy-compliant Storage Account used to host the installation script. |

## 🛠️ Key Technical Solutions & Troubleshooting

The project involved overcoming several common real-world deployment challenges:

### 1. Governance Policy Compliance
* **Challenge:** An existing Azure Policy assignment restricted storage accounts to only Geo-Redundant SKUs (e.g., `Standard_GRS`). The initial ARM template failed due to an attempt to deploy non-compliant storage.
* **Solution:** The storage resource was commented out of the main template, and a separate deployment was executed using the `azurestoragedeploy.json` template with the required `Standard_GRS` SKU, ensuring policy compliance.

### 2. Custom Script Extension (CSE) Fix
* **Challenge:** The initial deployment failed due to the VM Scale Set's Custom Script Extension not being able to interpret complex inline Base64 encoded PowerShell commands (Code: `VMExtensionProvisioningError`).
* **Solution:** The CSE was reconfigured to use the **File Download Method**. The `install-iis.ps1` script was uploaded to a publicly accessible Azure Blob Storage container, and the template was updated to use `fileUris` and a simple `commandToExecute`.

---

## 🔒 Security: Custom RBAC Implementation

To enforce the principle of **Least Privilege**, a custom Role-Based Access Control (RBAC) role was created and assigned at the Resource Group scope.

### Role Definition (`network-contributor-role.json`)
The custom role, **Limited Network Contributor**, grants highly specific permissions, preventing the user from managing critical network components (VNets, NSGs, Firewalls) while allowing them to manage VMSS network interfaces.

| Action | Purpose |
| :--- | :--- |
| `Microsoft.Network/loadBalancers/read` | Allows user to monitor the Load Balancer status. |
| `Microsoft.Network/networkInterfaces/write` | Allows user to perform necessary maintenance/configuration on the VMSS NICs. |

## 🔒 I. Governance: Geo-Redundancy Policy Enforcement

The project validated a critical organizational policy requiring Geo-Redundant storage for high availability and data residency compliance.

### The Policy
A pre-existing Azure Policy was assigned to the environment to **Deny** the creation of any Storage Account that does not use a Geo-Redundant SKU.

### The Validation (Policy Enforcement)
The initial deployment attempt, which defaulted to a non-compliant SKU, failed immediately.

> *The Azure Policy blocks the non-compliant deployment:*
> **![Policy Denial Screenshot](https://github.com/harsh103158/Azure-Governance-IAC-and-Security-Project/blob/7a203a8b2570a4b7cfb5905a3bbe5810bb0acace/images/Screenshot%202025-11-16%20014825.png)**

### The Solution
The Storage Account was successfully provisioned independently using the compliant parameter: **`storageSKU: Standard_GRS`**.

---

## 🛠️ II. Infrastructure Resilience Fixes

The deployment required significant troubleshooting to achieve a successful Provisioning State:

### A. Custom Script Extension (CSE) Fix
The VM Scale Set (VMSS) deployment initially failed due to the complex escaping rules required for inline Base64 encoding (Code: `VMExtensionProvisioningError`).

* **Resolution:** The configuration was updated to use the **File Download Method**. The `install-iis.ps1` script was hosted on a public blob, and the CSE was configured to download and execute it via `fileUris` and a simple `commandToExecute`.

### B. Final Success
All infrastructure issues (including dependencies and CSE) were resolved, resulting in a successful VMSS deployment.

> *Successful VMSS Deployment Proof:*
> ![powershell-vmss-deployment](https://github.com/harsh103158/Azure-Governance-IAC-and-Security-Project/blob/237ff01bd3c0415d531b2bdbc29c776c47c39f3d/images/Screenshot%202025-11-16%20205430.png)
> ![Successful Deployment After Fixes](https://github.com/harsh103158/Azure-Governance-IAC-and-Security-Project/blob/89f78e669f232cdb177f4b78382e20c5c345094d/images/Screenshot%202025-11-17%20033045.png)

---

## 🔐 III. Security: Least Privilege RBAC

The final step was to enforce the Principle of Least Privilege by creating a custom role definition and assigning it to a user.

### Custom Role: `Limited Network Contributor`
This custom role was created to restrict a user to only two specific actions, preventing them from modifying critical network infrastructure while allowing maintenance on the VM Scale Set's network interfaces (NICs).

| Action | Purpose |
| :--- | :--- |
| `Microsoft.Network/loadBalancers/read` | Allows viewing of the Load Balancer configuration. |
| `Microsoft.Network/networkInterfaces/write` | Allows maintenance on the VMSS Network Interfaces (NICs). |

### Role Creation & Assignment
The custom role was created by importing "network-contributor-file.json" file and was then successfully assigned.

```powershell
# 1. Define Variables
$subId = (Get-AzContext).Subscription.Id
$fullScope = "/subscriptions/$subId/resourcegroups/Rg-Prod"
$objectId = (Get-AzADUser -UserPrincipalName "harshvardhan@sanjeev902@gmail.com").Id 

# 2. Create the Role Definition (using dynamic substitution for scope)
New-AzRoleDefinition -inputfile "./network-contributor-role.json"
(Get-Content -Path "./network-contributor-role.json" -Raw) 

# 3. Assign the Custom Role
New-AzRoleAssignment -ObjectId $objectId `
    -RoleDefinitionName "Limited Network Contributor" `
    -Scope $fullScope
