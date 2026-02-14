# Network Architecture Diagram

This document provides detailed network architecture diagrams for the KBudget GPT application.

## Table of Contents

- [Overview](#overview)
- [Virtual Network Topology](#virtual-network-topology)
- [Subnet Layout](#subnet-layout)
- [Traffic Flow Diagrams](#traffic-flow-diagrams)
- [Security Boundaries](#security-boundaries)
- [Scaling Architecture](#scaling-architecture)

## Overview

The KBudget GPT application uses a multi-tier network architecture with dedicated subnets for each application tier. This design provides:

- **Security**: Network segmentation with NSG-based access control
- **Scalability**: Each tier can scale independently
- **Performance**: Service endpoints for optimized Azure service access
- **Isolation**: Workload segregation following defense-in-depth principles

## Virtual Network Topology

### High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                          Azure Subscription                                    │
│                    KBudget GPT Application Infrastructure                      │
└────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                      Resource Group: kbudget-{env}-rg                          │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐ │
│  │            Virtual Network: kbudget-{env}-vnet                           │ │
│  │              Address Space: 10.x.0.0/16 (65,536 IPs)                     │ │
│  ├──────────────────────────────────────────────────────────────────────────┤ │
│  │                                                                          │ │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │ │
│  │  │         Frontend Subnet: 10.x.4.0/24 (256 IPs)                     │ │ │
│  │  │  ┌──────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  NSG: frontend-nsg                                           │  │ │ │
│  │  │  │  • Allow HTTPS (443) ← Internet                              │  │ │ │
│  │  │  │  • Allow HTTP (80) ← Internet                                │  │ │ │
│  │  │  │  • Deny all other inbound                                    │  │ │ │
│  │  │  └──────────────────────────────────────────────────────────────┘  │ │ │
│  │  │  ┌──────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  Service Endpoints:                                          │  │ │ │
│  │  │  │  • Microsoft.Web                                             │  │ │ │
│  │  │  │  • Microsoft.Storage                                         │  │ │ │
│  │  │  │  • Microsoft.KeyVault                                        │  │ │ │
│  │  │  └──────────────────────────────────────────────────────────────┘  │ │ │
│  │  │  Workloads: Load Balancer, Application Gateway, Public Web Apps  │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                          │ │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │ │
│  │  │      Application Subnet: 10.x.1.0/24 (256 IPs)                     │ │ │
│  │  │  ┌──────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  NSG: app-nsg                                                │  │ │ │
│  │  │  │  • Allow HTTPS (443) ← All                                   │  │ │ │
│  │  │  │  • Allow HTTP (80) ← All                                     │  │ │ │
│  │  │  └──────────────────────────────────────────────────────────────┘  │ │ │
│  │  │  ┌──────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  Delegation: Microsoft.Web/serverFarms                       │  │ │ │
│  │  │  │  Service Endpoints:                                          │  │ │ │
│  │  │  │  • Microsoft.Web                                             │  │ │ │
│  │  │  │  • Microsoft.Storage                                         │  │ │ │
│  │  │  │  • Microsoft.Sql                                             │  │ │ │
│  │  │  │  • Microsoft.KeyVault                                        │  │ │ │
│  │  │  └──────────────────────────────────────────────────────────────┘  │ │ │
│  │  │  Workloads: App Service, Web Apps, APIs                            │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                          │ │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │ │
│  │  │       Database Subnet: 10.x.2.0/24 (256 IPs)                       │ │ │
│  │  │  ┌──────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  NSG: db-nsg                                                 │  │ │ │
│  │  │  │  • Allow SQL (1433) ← 10.x.1.0/24 (app-subnet) ONLY          │  │ │ │
│  │  │  │  • Deny all other inbound                                    │  │ │ │
│  │  │  └──────────────────────────────────────────────────────────────┘  │ │ │
│  │  │  ┌──────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  Service Endpoints:                                          │  │ │ │
│  │  │  │  • Microsoft.Sql                                             │  │ │ │
│  │  │  └──────────────────────────────────────────────────────────────┘  │ │ │
│  │  │  Workloads: SQL Managed Instance, Private Endpoints               │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                          │ │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │ │
│  │  │      Functions Subnet: 10.x.3.0/24 (256 IPs)                       │ │ │
│  │  │  ┌──────────────────────────────────────────────────────────────┐  │ │ │
│  │  │  │  Delegation: Microsoft.Web/serverFarms                       │  │ │ │
│  │  │  │  Service Endpoints:                                          │  │ │ │
│  │  │  │  • Microsoft.Web                                             │  │ │ │
│  │  │  │  • Microsoft.Storage                                         │  │ │ │
│  │  │  │  • Microsoft.Sql                                             │  │ │ │
│  │  │  │  • Microsoft.KeyVault                                        │  │ │ │
│  │  │  └──────────────────────────────────────────────────────────────┘  │ │ │
│  │  │  Workloads: Azure Functions, Background Jobs                       │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                          │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

## Subnet Layout

### Address Space Allocation

| Environment | VNet CIDR | Frontend | Application | Database | Functions | Available |
|-------------|-----------|----------|-------------|----------|-----------|-----------|
| Development | 10.0.0.0/16 | 10.0.4.0/24 | 10.0.1.0/24 | 10.0.2.0/24 | 10.0.3.0/24 | ~64K IPs |
| Staging | 10.1.0.0/16 | 10.1.4.0/24 | 10.1.1.0/24 | 10.1.2.0/24 | 10.1.3.0/24 | ~64K IPs |
| Production | 10.2.0.0/16 | 10.2.4.0/24 | 10.2.1.0/24 | 10.2.2.0/24 | 10.2.3.0/24 | ~64K IPs |

### Subnet Details

```
┌────────────────────────────────────────────────────────────────────────┐
│                    VNet: 10.x.0.0/16 (65,536 IPs)                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Frontend Subnet                                                       │
│  ├─ CIDR: 10.x.4.0/24                                                  │
│  ├─ Total IPs: 256                                                     │
│  ├─ Usable IPs: 251 (Azure reserves 5)                                 │
│  ├─ Purpose: Public-facing tier                                        │
│  └─ Security: frontend-nsg                                             │
│                                                                        │
│  Application Subnet                                                    │
│  ├─ CIDR: 10.x.1.0/24                                                  │
│  ├─ Total IPs: 256                                                     │
│  ├─ Usable IPs: 251                                                    │
│  ├─ Purpose: App Service, APIs                                         │
│  ├─ Security: app-nsg                                                  │
│  └─ Delegation: Microsoft.Web/serverFarms                              │
│                                                                        │
│  Database Subnet                                                       │
│  ├─ CIDR: 10.x.2.0/24                                                  │
│  ├─ Total IPs: 256                                                     │
│  ├─ Usable IPs: 251                                                    │
│  ├─ Purpose: SQL Database, data tier                                   │
│  └─ Security: db-nsg (restricted access)                               │
│                                                                        │
│  Functions Subnet                                                      │
│  ├─ CIDR: 10.x.3.0/24                                                  │
│  ├─ Total IPs: 256                                                     │
│  ├─ Usable IPs: 251                                                    │
│  ├─ Purpose: Serverless compute                                        │
│  └─ Delegation: Microsoft.Web/serverFarms                              │
│                                                                        │
│  Unallocated Space                                                     │
│  └─ Available for future growth: ~64,000 IPs                           │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow Diagrams

### User Request Flow (Read Operation)

```
┌──────────┐
│ Internet │
│  User    │
└────┬─────┘
     │
     │ (1) HTTPS Request
     │     Port: 443
     ▼
┌─────────────────────────────────┐
│  Frontend Subnet (10.x.4.0/24)  │
│  ┌───────────────────────────┐  │
│  │   Application Gateway     │  │
│  │   or Load Balancer        │  │
│  └───────────┬───────────────┘  │
└──────────────┼──────────────────┘
               │
               │ (2) Internal Route
               │     Within VNet
               ▼
┌─────────────────────────────────┐
│ Application Subnet (10.x.1.0/24)│
│  ┌───────────────────────────┐  │
│  │   App Service             │  │
│  │   Web Application         │  │
│  └───────────┬───────────────┘  │
└──────────────┼──────────────────┘
               │
               │ (3) SQL Query
               │     Port: 1433
               │     Via Service Endpoint
               ▼
┌─────────────────────────────────┐
│  Database Subnet (10.x.2.0/24)  │
│  ┌───────────────────────────┐  │
│  │   Azure SQL Database      │  │
│  │   (Private Endpoint)      │  │
│  └───────────┬───────────────┘  │
└──────────────┼──────────────────┘
               │
               │ (4) Query Result
               │
               ▼
        (Return path reverses flow)
```

### Background Job Flow

```
┌─────────────────────────────────┐
│ Functions Subnet (10.x.3.0/24)  │
│  ┌───────────────────────────┐  │
│  │   Azure Functions         │  │
│  │   (Timer Trigger)         │  │
│  └───┬───────────────────┬───┘  │
└──────┼───────────────────┼──────┘
       │                   │
       │ (1) Read Config   │ (2) Process Data
       │ Via Service       │ Port: 1433
       │ Endpoint          │ Via Service Endpoint
       ▼                   ▼
┌──────────────┐   ┌─────────────────────────────┐
│ Key Vault    │   │ Database Subnet (10.x.2.0/24)│
│ (Secrets)    │   │ ┌─────────────────────────┐  │
└──────────────┘   │ │ Azure SQL Database      │  │
       │           │ └─────────┬───────────────┘  │
       │           └───────────┼──────────────────┘
       │                       │
       │ (3) Write Results     │
       │     Via Service       │
       │     Endpoint          │
       ▼                       │
┌──────────────┐               │
│ Storage      │◄──────────────┘
│ Account      │
└──────────────┘
```

### Service Endpoint Traffic

```
Application Subnet (10.x.1.0/24)
        │
        │ Private Traffic
        │ (No internet routing)
        │
        ├────────────────────────┐
        │                        │
        ▼                        ▼
┌───────────────┐        ┌───────────────┐
│ SQL Database  │        │ Storage       │
│ Service       │        │ Account       │
│ Endpoint      │        │ Service       │
│               │        │ Endpoint      │
└───────────────┘        └───────────────┘
        │                        │
        └────────┬───────────────┘
                 │
                 ▼
        Azure Backbone Network
        (Private, optimized routing)
```

## Security Boundaries

### Network Security Groups (NSG) Rules

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          Frontend NSG Rules                              │
├──────────────────────────────────────────────────────────────────────────┤
│ Priority │ Name        │ Direction │ Access │ Protocol │ Source │ Port   │
├──────────┼─────────────┼───────────┼────────┼──────────┼────────┼────────┤
│   100    │ AllowHTTPS  │ Inbound   │ Allow  │ TCP      │ Internet│ 443   │
│   110    │ AllowHTTP   │ Inbound   │ Allow  │ TCP      │ Internet│ 80    │
│   65000  │ DenyAllIn   │ Inbound   │ Deny   │ All      │ *      │ *     │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                        Application NSG Rules                             │
├──────────────────────────────────────────────────────────────────────────┤
│ Priority │ Name        │ Direction │ Access │ Protocol │ Source │ Port   │
├──────────┼─────────────┼───────────┼────────┼──────────┼────────┼────────┤
│   100    │ AllowHTTPS  │ Inbound   │ Allow  │ TCP      │ *      │ 443   │
│   110    │ AllowHTTP   │ Inbound   │ Allow  │ TCP      │ *      │ 80    │
│   65000  │ DenyAllIn   │ Inbound   │ Deny   │ All      │ *      │ *     │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                         Database NSG Rules                               │
├──────────────────────────────────────────────────────────────────────────┤
│ Priority │ Name          │ Direction │ Access │ Protocol │ Source    │ Port│
├──────────┼───────────────┼───────────┼────────┼──────────┼───────────┼─────┤
│   100    │ AllowSQL      │ Inbound   │ Allow  │ TCP      │10.x.1.0/24│ 1433│
│          │ FromAppSubnet │           │        │          │(App)      │     │
│   65000  │ DenyAllIn     │ Inbound   │ Deny   │ All      │ *         │ *   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Defense in Depth

```
Layer 1: Internet Boundary
┌─────────────────────────────────────────┐
│ Azure DDoS Protection                   │
│ - Basic (free) or Standard              │
│ - 20 Tbps mitigation capacity           │
└─────────────────────────────────────────┘
                  ▼
Layer 2: Network Perimeter
┌─────────────────────────────────────────┐
│ Frontend NSG                            │
│ - Allow only HTTPS/HTTP                 │
│ - Block all other protocols             │
└─────────────────────────────────────────┘
                  ▼
Layer 3: Application Tier
┌─────────────────────────────────────────┐
│ Application NSG                         │
│ - Subnet delegation                     │
│ - Service endpoints (no internet)       │
└─────────────────────────────────────────┘
                  ▼
Layer 4: Data Tier
┌─────────────────────────────────────────┐
│ Database NSG                            │
│ - Allow only from app-subnet            │
│ - SQL firewall rules                    │
│ - Service endpoints                     │
└─────────────────────────────────────────┘
                  ▼
Layer 5: Data Encryption
┌─────────────────────────────────────────┐
│ SQL Database                            │
│ - TDE (Transparent Data Encryption)     │
│ - Column-level encryption               │
│ - Always Encrypted                      │
└─────────────────────────────────────────┘
```

## Scaling Architecture

### Horizontal Scaling Capacity

```
┌───────────────────────────────────────────────────────────────────────┐
│                     Frontend Subnet (10.x.4.0/24)                     │
│                         251 usable IP addresses                       │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Current: 2 instances                    Future: Up to 250 instances │
│  ┌──────┐ ┌──────┐                      ┌──────┐ ┌──────┐ ┌──────┐ │
│  │ LB 1 │ │ AG 1 │  ... can scale to .. │ LB n │ │ AG n │ │Web n │ │
│  └──────┘ └──────┘                      └──────┘ └──────┘ └──────┘ │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                   Application Subnet (10.x.1.0/24)                    │
│                         251 usable IP addresses                       │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Current: 3 instances                    Future: Up to 250 instances │
│  ┌──────┐ ┌──────┐ ┌──────┐            ┌──────┐ ┌──────┐ ┌──────┐ │
│  │App 1 │ │App 2 │ │App 3 │ ... scale..│App n │ │API n │ │Web n │ │
│  └──────┘ └──────┘ └──────┘            └──────┘ └──────┘ └──────┘ │
│                                                                       │
│  Auto-scaling based on:                                               │
│  • CPU utilization > 70%                                              │
│  • Memory utilization > 80%                                           │
│  • HTTP queue length > 100                                            │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                    Functions Subnet (10.x.3.0/24)                     │
│                         251 usable IP addresses                       │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Current: 1 instance                     Future: Elastic scaling     │
│  ┌──────┐                                ┌──────┐ ┌──────┐ ┌──────┐ │
│  │Func 1│  ... auto-scales based on .. │Func n│ │Func n│ │Func n│ │
│  └──────┘      demand and queue depth   └──────┘ └──────┘ └──────┘ │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### Vertical Scaling Options

If you exhaust the /24 subnet (256 IPs), you can:

1. **Expand subnet** from /24 to /23 (512 IPs) or /22 (1,024 IPs)
   - Requires subnet recreation
   - Involves brief downtime

2. **Add new subnets** using available address space
   - 10.x.5.0/24, 10.x.6.0/24, etc.
   - No downtime
   - Can be done dynamically

3. **VNet peering** to connect multiple VNets
   - Scale beyond single VNet limits
   - No downtime
   - Cross-region support

### Future Expansion Map

```
Current Allocation (4 subnets):
┌─────────────────────────────────────────────────────────┐
│ 10.x.0.0/24  │ Reserved for Azure                       │
│ 10.x.1.0/24  │ Application Subnet                       │
│ 10.x.2.0/24  │ Database Subnet                          │
│ 10.x.3.0/24  │ Functions Subnet                         │
│ 10.x.4.0/24  │ Frontend Subnet                          │
│ 10.x.5.0/24  │ Available (future AKS cluster)           │
│ 10.x.6.0/24  │ Available (future App Gateway)           │
│ 10.x.7.0/24  │ Available (future Bastion)               │
│ ...          │ ...                                      │
│ 10.x.255.0/24│ Available (254 more /24 subnets)         │
└─────────────────────────────────────────────────────────┘
```

## Environment Comparison

```
┌──────────────┬─────────────────┬─────────────────┬─────────────────┐
│ Feature      │ Development     │ Staging         │ Production      │
├──────────────┼─────────────────┼─────────────────┼─────────────────┤
│ Address Space│ 10.0.0.0/16     │ 10.1.0.0/16     │ 10.2.0.0/16     │
│ Frontend     │ 10.0.4.0/24     │ 10.1.4.0/24     │ 10.2.4.0/24     │
│ Application  │ 10.0.1.0/24     │ 10.1.1.0/24     │ 10.2.1.0/24     │
│ Database     │ 10.0.2.0/24     │ 10.1.2.0/24     │ 10.2.2.0/24     │
│ Functions    │ 10.0.3.0/24     │ 10.1.3.0/24     │ 10.2.3.0/24     │
│ DDoS         │ Basic (Free)    │ Basic (Free)    │ Standard        │
│ NSG Rules    │ Same across all environments                       │
│ Service EP   │ Enabled         │ Enabled         │ Enabled         │
│ Monitoring   │ Basic           │ Enhanced        │ Full + Alerts   │
└──────────────┴─────────────────┴─────────────────┴─────────────────┘
```

## Deployment Sequence

```
Step 1: Create Resource Group
        ┌─────────────────────────┐
        │ kbudget-{env}-rg        │
        └───────────┬─────────────┘
                    │
Step 2: Deploy VNet and NSGs
        ┌───────────▼─────────────┐
        │ Virtual Network         │
        │ + 3 NSGs                │
        └───────────┬─────────────┘
                    │
Step 3: Create Subnets (in parallel)
        ┌───────────▼─────────────┐
        │ ┌────────┐ ┌────────┐   │
        │ │Frontend│ │  App   │   │
        │ └────────┘ └────────┘   │
        │ ┌────────┐ ┌────────┐   │
        │ │Database│ │Functions│  │
        │ └────────┘ └────────┘   │
        └───────────┬─────────────┘
                    │
Step 4: Configure Service Endpoints
        ┌───────────▼─────────────┐
        │ Enable endpoints:       │
        │ • Microsoft.Web         │
        │ • Microsoft.Storage     │
        │ • Microsoft.Sql         │
        │ • Microsoft.KeyVault    │
        └───────────┬─────────────┘
                    │
Step 5: Deploy Application Resources
        ┌───────────▼─────────────┐
        │ App Service, Functions, │
        │ SQL DB, Storage, etc.   │
        └─────────────────────────┘
```

## Monitoring and Diagnostics

Recommended monitoring for VNet:

```
┌────────────────────────────────────────────────────────────┐
│                    Network Monitoring                      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Azure Monitor                                             │
│  ├─ VNet Metrics                                           │
│  │  ├─ Bytes In/Out                                        │
│  │  ├─ Packets In/Out                                      │
│  │  └─ Dropped Packets                                     │
│  │                                                          │
│  ├─ NSG Flow Logs                                          │
│  │  ├─ Allowed traffic                                     │
│  │  ├─ Denied traffic                                      │
│  │  └─ Traffic patterns                                    │
│  │                                                          │
│  ├─ Network Watcher                                        │
│  │  ├─ Connection Monitor                                  │
│  │  ├─ IP Flow Verify                                      │
│  │  └─ Next Hop                                            │
│  │                                                          │
│  └─ Alerts                                                 │
│     ├─ High packet drop rate                               │
│     ├─ NSG rule changes                                    │
│     └─ Subnet IP exhaustion                                │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

## Summary

This network architecture provides:

✅ **Security**: Multi-layer defense with NSGs, service endpoints, and network segmentation  
✅ **Scalability**: 251 usable IPs per subnet, room for 64K+ total IPs  
✅ **Performance**: Service endpoints for optimized Azure service access  
✅ **Isolation**: Dedicated subnets for each application tier  
✅ **Flexibility**: Environment-specific configurations  
✅ **Cost Efficiency**: Free VNet and NSGs, optional DDoS Standard for production  

For deployment instructions, see the [README](../../../infrastructure/arm-templates/virtual-network/README.md) in the virtual-network directory.
