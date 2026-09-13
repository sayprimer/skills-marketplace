# Audience API-key contract

Generated from the primer-platform Zod/OpenAPI source the server serves — the mechanical shape
of the 16 API-key operations the `audience-refiner` skill and its `bin/primer` CLI drive. Do not
edit by hand; after the source schemas change, regenerate:

```bash
UPDATE_API_CONTRACT_MD=1 TS_NODE_TRANSPILE_ONLY=1 npm run test -w @primer/primer-platform -- tests/skillsMarketplace/apiContract.test.ts
```

Usage and judgment — which CLI verb maps to which endpoint, when to poll, what to send, auth and
rate limits — live in `SKILL.md` and `reference/configuration.md`, not here.

## Endpoints

### `GET /audiences`

List the organization's audiences. Supports pagination (offset/limit), sorting (sort/order), and filtering by name, status, destinations, creator, type, error, and favorite.

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `query` | `offset` | no | string | `"0"` | Used for paginating. How many entries should be skipped. |
| `query` | `limit` | no | string | `"50"` | Used for paginating. How many entries should be returned after the offset. |
| `query` | `sort` | no | enum(`name`, `size`, `status`, `updated_at`, `created_by`, `created_at`) |  | Property name of the sorting. |
| `query` | `order` | no | enum(`ASC`, `DESC`) |  | Order rule for the sorted property. |
| `query` | `name` | no | string |  | Full or partial name of the search audience |
| `query` | `status` | no | string |  | Specifies a filter for audiences based on their status. This field accepts an array of status values, allowing for the selection of audiences that match any of the provided statuses. The statuses should be separated by commas when used in a query parameter. |
| `query` | `destinations` | no | string |  | Specifies a filter for audiences based on their destinations. This field accepts an array of destinations values, allowing for the selection of audiences that match any of the provided destinations. The statuses should be separated by commas when used in a query parameter. |
| `query` | `createdBy` | no | string | `""` | Specifies a filter for audiences based on their created by. This field accepts an array of created by values, allowing for the selection of audiences that match any of the provided created by. The created by should be separated by commas when used in a query parameter. |
| `query` | `error` | no | enum(`true`, `false`) |  | Include only audiences with error |
| `query` | `favorite` | no | enum(`true`, `false`) |  | Include only user favorited audiences |
| `query` | `type` | no | string |  | Filter audiences by type. Accepts a comma-separated list of audience types; when omitted, every type except ICP definitions is returned. |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | List of audiences matching the filter, sorting and page | { `paginationDetails`, `audiences` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Audience |  |

### `POST /audiences`

Create or Duplicate an audience.

**Parameters**

None.

**Request Body**

Content-Type `application/json`: { `name`, `destinations`, `source_criteria`, `initial`, `chat_id`, `type` }.
| Field | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- |
| `chat_id` | no | string |  | Chat ID to link with this audience when the chat was started before the audience existed |
| `destinations` | no | { `meta`, `google`, `linkedIn`, `reddit`, `dv360`, `salesforce`, `csv` } | `{}` | Specifies the destinations for the audience, detailing where the audience data is utilized or exported. |
| `initial` | no | { `source_criteria`, `estimate` } \| null |  | The previous shape of the audience. |
| `name` | no | string |  | The name of the new audience. |
| `source_criteria` | no | { `target_entity_type`, `group` } \| null |  | The source criteria of the audience. |
| `type` | no | enum(`regular`, `exclusion`, `conversion_report`) | `"regular"` | Type of audience to create. |

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `201` | Audience created with data. | { `estimateUpdated`, `updatedAudience` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Audience |  |
| `404` | Audience not found | string |

### `GET /audiences/{audienceId}`

Get audience by its id

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `path` | `audienceId` | yes | string |  | Audience Id |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | Audience retrieved with data. | { `id`, `name`, `status`, `subStatus`, `isFavorite`, `isArchived`, `archivedAt`, `mode`, `type`, `shape`, `destinations`, `companies`, `people`, `lastUpdatedAt`, `submittedAt`, `hasError`, `errors`, `syncSettings`, `isAudienceRunForLatestAudienceShape`, `latestAudienceRun`, `failedSyncsProviders`, `clawbacked`, `clawbackSource`, `isLive`, `lastAdPlatformSync`, `syncedDestinations`, `confirmedDestinations`, `confirmedShapeId`, `syncsAudiences`, `hasDelayedRun`, `delayedRunSecondsRemaining` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Audience |  |
| `404` | Audience not found | string |

### `PATCH /audiences/{audienceId}`

Update audience properties (name, destinations, or archived flag). Returns the updated audience. Note: setting `archived: true` triggers an irreversible ad-audience clawback; API-key callers should send only `destinations`.

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `path` | `audienceId` | yes | string |  | Audience Id |

**Request Body**

Content-Type `application/json`: The updatable fields of an audience: its name, archived flag, and destinations.
| Field | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- |
| `archived` | no | boolean |  | When true, archives the audience; when false, unarchives it. Archiving triggers an irreversible ad-audience clawback, so API-key callers should send only `destinations` and omit this field. |
| `destinations` | no | { `meta`, `google`, `linkedIn`, `reddit`, `dv360`, `salesforce`, `csv` } |  | Specifies the destinations for the audience, detailing where the audience data is utilized or exported. |
| `name` | no | string |  | The new name for the audience. |

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | The updated audience. | { `id`, `name`, `status`, `subStatus`, `isFavorite`, `isArchived`, `archivedAt`, `mode`, `type`, `shape`, `destinations`, `companies`, `people`, `lastUpdatedAt`, `submittedAt`, `hasError`, `errors`, `syncSettings`, `isAudienceRunForLatestAudienceShape`, `latestAudienceRun`, `failedSyncsProviders`, `clawbacked`, `clawbackSource`, `isLive`, `lastAdPlatformSync`, `syncedDestinations`, `confirmedDestinations`, `confirmedShapeId`, `syncsAudiences`, `hasDelayedRun`, `delayedRunSecondsRemaining` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Audience |  |
| `404` | Audience not found | string |

### `POST /audiences/{audienceId}/shape`

Create a new shape (filter criteria revision) for an audience. Returns whether the estimate was updated and the updated audience.

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `path` | `audienceId` | yes | string |  | Audience Id |

**Request Body**

Content-Type `application/json`: { `source_criteria`, `enrichments` }.
| Field | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- |
| `enrichments` | no | any \| null |  | Optional enrichment selections for the shape. Currently unused by the server; may be omitted. |
| `source_criteria` | no | { `target_entity_type`, `group` } |  | The filter criteria that define the new shape. |

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | The updated audience and whether its estimate changed. | { `estimateUpdated`, `updatedAudience` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Audience |  |
| `404` | Audience not found | string |

### `GET /criterias/estimate`

Get the current estimate for an audience

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `query` | `audienceId` | no | string \| null |  | Audience Id |
| `query` | `isFinalCall` | no | boolean \| null |  | Is final polling call |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | Current audience estimate | { `people_count`, `companies_count`, `preview`, `match_rate`, `heuristics`, `started_at`, `finished_at` } |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `404` | Audience or estimate not found not found | string |

### `GET /audiences/{audienceId}/{shapeId}/estimate/heuristics`

Deprecated. This endpoint no longer returns estimate heuristics and responds with 204 No Content on success; use GET /criterias/estimate instead.

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `path` | `audienceId` | yes | string |  | Audience Id |
| `path` | `shapeId` | yes | string |  | Shape Id |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `204` | No content successfully |  |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Audience |  |
| `404` | Audience not found | string |

### `GET /filters/field-values`

Get the list of possible field values

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `query` | `fieldId` | yes | enum(`person_location`, `company_location`, `domain`, `industry`, `keywords`, `technologies`, `departments`, `job_title`, `seniority`, `annual_revenue`, `founded_year`, `headcount`, `csv`, `naics_code`, `skills`, `majors`, `degrees`, `last_seen`, `first_seen`, `last_form_submission`, `num_visits`, `session_time`, `num_form_fills`, `form_name`, `latest_page_url`, `referrer_domain`, `device_type`, `browser`, `utm_source`, `utm_medium`, `utm_term`, `utm_content`, `utm_campaign`, `first_utm_source`, `first_utm_medium`, `first_utm_campaign`, `first_utm_term`, `first_utm_content`, `all_utm_source`, `all_utm_medium`, `all_utm_campaign`, `all_utm_term`, `all_utm_content`, `first_page_url`, `all_pages_visited`, `intent_level`, `traffic_type`, `audience_membership`, `person_name`, `company_account_type`) |  | Requested field identifier. |
| `query` | `q` | no | string | `""` | Query string. |
| `query` | `limit` | no | string | `"250"` | How many entries should be returned. |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | List of filter value suggestions | array<{ `value`, `label`, `category` }> |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `404` | Filter not found | string |

### `POST /filters/find-values`

Get the list of values present in database

**Parameters**

None.

**Request Body**

Content-Type `application/json`: { `fieldId`, `values` }.
| Field | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- |
| `fieldId` | yes | enum(`person_location`, `company_location`, `domain`, `industry`, `keywords`, `technologies`, `departments`, `job_title`, `seniority`, `annual_revenue`, `founded_year`, `headcount`, `csv`, `naics_code`, `skills`, `majors`, `degrees`, `last_seen`, `first_seen`, `last_form_submission`, `num_visits`, `session_time`, `num_form_fills`, `form_name`, `latest_page_url`, `referrer_domain`, `device_type`, `browser`, `utm_source`, `utm_medium`, `utm_term`, `utm_content`, `utm_campaign`, `first_utm_source`, `first_utm_medium`, `first_utm_campaign`, `first_utm_term`, `first_utm_content`, `all_utm_source`, `all_utm_medium`, `all_utm_campaign`, `all_utm_term`, `all_utm_content`, `first_page_url`, `all_pages_visited`, `intent_level`, `traffic_type`, `audience_membership`, `person_name`, `company_account_type`) |  | Requested field identifier. |
| `values` | yes | array<string> |  | The list of values to search for within the field's known values. |

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | List of values present in picklist | array<{ `value`, `label` }> |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `404` | Filter not found | string |

### `POST /imported-datasets`

Create imported dataset.

**Parameters**

None.

**Request Body**

Content-Type `application/json`: { `name`, `entityType`, `inputCount`, `validCount`, `invalidCount`, `fieldMappings` }.
| Field | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- |
| `entityType` | yes | enum(`company`, `person`) |  | Dataset entity type |
| `fieldMappings` | yes | { `firstName`, `lastName`, `companyDomain`, `linkedinUrl`, `email` } |  | Maps the dataset's source columns to Primer identity fields (firstName, lastName, companyDomain, linkedinUrl, email). |
| `inputCount` | yes | number |  | Total number of rows in input file |
| `invalidCount` | yes | number |  | Number of invalid rows in input file |
| `name` | yes | string |  | The name of the new dataset. |
| `validCount` | yes | number |  | Number of valid rows in input file |

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `201` | Imported dataset created with data. | { `rawPresignedUrl`, `translatedPresignedUrl`, `datasetId`, `name`, `sourceFormat`, `status`, `entityType`, `inputCount`, `validCount`, `invalidCount`, `fieldMappings` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Imported dataset |  |

### `GET /imported-datasets`

Get imported datasets

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `query` | `offset` | no | string |  | Pagination offset |
| `query` | `limit` | no | string |  | Pagination limit |
| `query` | `status` | no | enum(`initiated`, `completed`, `failed`) \| null |  | Dataset status |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | Imported Datasets are retrieved. | array<{ `id`, `name`, `entityType`, `status`, `mappingTable`, `inputCount`, `validCount`, `invalidCount`, `fieldMappings`, `error`, `stats`, `isSyncing`, `syncedAt`, `createdAt`, `activeAudiences`, `origin` }> |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Imported datasets |  |
| `404` | Imported Datasets not found | string |

### `GET /imported-datasets/{datasetId}`

Get imported dataset by id

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `path` | `datasetId` | yes | string |  | Dataset id |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | Dataset is retrieved. | { `id`, `name`, `entityType`, `status`, `mappingTable`, `inputCount`, `validCount`, `invalidCount`, `fieldMappings`, `error`, `stats`, `isSyncing`, `syncedAt`, `createdAt`, `activeAudiences`, `origin` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Imported dataset |  |
| `404` | Imported Dataset not found | string |

### `POST /imported-datasets/{datasetId}/import`

Import dataset

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `path` | `datasetId` | yes | string |  | Dataset id |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `200` | Dataset import started. | { `id`, `name`, `entityType`, `status`, `mappingTable`, `inputCount`, `validCount`, `invalidCount`, `fieldMappings`, `error`, `stats`, `isSyncing`, `syncedAt`, `createdAt`, `activeAudiences`, `origin` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Imported dataset |  |
| `404` | Imported Dataset not found | string |

### `DELETE /imported-datasets/{datasetId}`

Delete imported dataset.

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `path` | `datasetId` | yes | string |  | Dataset id |

**Request Body**

None.

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `204` | Dataset is deleted successfully |  |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
| `403` | Authenticated user doesn't have access to Imported Dataset |  |
| `404` | Imported Dataset not found | string |

### `POST /ingest/people`

Push people rows into a first-party imported dataset. API key (`ak_`) only.

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `query` | `dataset` | no | string |  | Logical dataset name. Defaults to `from_api`; must sanitize to a non-empty filename segment without `-batch-`. |
| `query` | `id_field` | no | string |  | Record field to use as the stable id. Defaults to `id`; must sanitize to a non-empty header name without path separators or `-batch-`. |

**Request Body**

Content-Type `application/json`: A single record object, an array of records, or an envelope containing `records`.
| Field | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- |
| `dataset` | no | string |  | Logical dataset name. Query parameter wins when both are present. |
| `id_field` | no | string |  | Stable id field. Query parameter wins when both are present. |
| `records` | yes | array<object> |  | Records to upsert into the dataset. |

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `202` | Rows buffered | { `accepted` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |

### `POST /ingest/companies`

Push company rows into a first-party imported dataset. API key (`ak_`) only.

**Parameters**

| In | Name | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `query` | `dataset` | no | string |  | Logical dataset name. Defaults to `from_api`; must sanitize to a non-empty filename segment without `-batch-`. |
| `query` | `id_field` | no | string |  | Record field to use as the stable id. Defaults to `id`; must sanitize to a non-empty header name without path separators or `-batch-`. |

**Request Body**

Content-Type `application/json`: A single record object, an array of records, or an envelope containing `records`.
| Field | Required | Schema | Default | Description |
| --- | --- | --- | --- | --- |
| `dataset` | no | string |  | Logical dataset name. Query parameter wins when both are present. |
| `id_field` | no | string |  | Stable id field. Query parameter wins when both are present. |
| `records` | yes | array<object> |  | Records to upsert into the dataset. |

**Responses**

| Status | Description | Body |
| --- | --- | --- |
| `202` | Rows buffered | { `accepted` } |
| `400` | Invalid params or payload | array<{ `code`, `expected`, `received`, `path`, `message`, `options` }> |
| `401` | Request doesn't have needed authentication parameters. Please check `Available authorizations` section here (symbol with lock on endpoint row) |  |
