# ChangeLog

## 1.6.0

### Features

- Adding possibility to run separate api and indexer deployment. More information on this can be found [here](https://docs.blockscout.com/for-developers/information-and-settings/separate-indexer-web-app-and-api). The minimum required backend version is 6.6.0

## 1.5.1

### Fixes

- Do not refer to `envFromSecret` when not defined for backend/frontend

## 1.5.0

### Feature

- Add PodMonitor for frontend

## 1.4.4

### Feature

- Add `extraEnv` and `envFrom` for backend/frontend to refer to an existing Secret/ConfigMap
- Create Secrets for backend/frontend only when data is specified

## 1.4.3

### Fixes

- Making stats configmap name unique

## 1.4.2

### Fixes

- Fixing stats url condition in frontend deployment

## 1.4.1

### Fixes

- Fixing stats volume attachment

## 1.4.0

### Feature

- Adding user-ops-indexer service

## 1.3.4

### Fixes

- Fixed custom TLS secret name reference for frontend and stats ingresses

## 1.3.3

### Feature

- Custom secret name for ingress TLS

## 1.3.2

### Fixes

- Dual token condition for gnosis chain

## 1.3.1

### Feature

- Adding dualToken parameter for networks like Gnosis Chain

## 1.3.0

### Feature

- Update blockscout app to 5.3.0
- Decrease blockscout frontend initialDelaySeconds to 30

## 1.2.0

### Feature

- Stats currency symbol now is passed from ```config.network.currency.symbol``` (Stats version 1.4.1 and above required)

## 1.1.4

### Fixes

- Adjust default frontend resource
- Increase default servicemonitor timeout

## 1.1.3

### Fixes

- Fixing path for auth

## 1.1.2

### Fixes

- Fixing path to /sitemap.xml

## 1.1.1

### Fixes

- Fixing path to /socket

## 1.1.0

### Features

- Updating ingress paths for frontend and backend (this change requires at least v1.9.0 of frontend and 5.2.2 for backend)

## 1.0.4

### Features

- Added README, CHANGELOG

### Fixes

- Fixed fixing prometheus serviceMonitor always on [issue](https://github.com/blockscout/helm-charts/issues/1)
