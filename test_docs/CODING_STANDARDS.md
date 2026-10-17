# SapiensCore Coding Standards

## Variable Naming

- **Lists of objects**: `listUser`, `listLocation`, `listPulseBox` — NEVER plurals like `users`, `locations`
- **IDs**: `idLocation`, `idUser`, `idPulseBox` — NEVER `locationId`, `userId`
- **Dropdown options**: `listLocationOption`, `listGameOption`
- **Tokens**: `tokenNew`, `tokenList`, `tokenOpen`

## Model Pattern (AutoDb/AutoRecord)

Every model follows this exact structure:

```php
class MyModel
{
    const STATUS_APPROVED = 1;
    const STATUS_APPROVED_TXT = 'my_model.status.approved';

    private AutoRecord $record;
    private AutoDb $autoDb;

    public const string TB_MY_MODEL = 'my_model';

    // Constructor: load existing or create new
    public function __construct(AutoDb $autoDb, $primarykey = 0)
    {
        $this->autoDb = $autoDb;
        if ($primarykey > 0) {
            $this->record = $autoDb->row(self::TB_MY_MODEL, 'id_my_model', $primarykey);
        } else {
            $this->record = $autoDb->newRow(self::TB_MY_MODEL);
        }
    }

    public function store()
    {
        $this->record->save();
    }

    // Getters/setters via $this->record->attr()
    public function getId()
    {
        return $this->record->attr('id_my_model');
    }

    // create(): validate → set → return (caller calls ->store())
    public static function create(array $attributes): MyModel
    {
        if (!Helper::issetInArray($attributes, array('name'))) {
            ExceptionHelper::throwEssentialInformationMissing(T::t('my_model.label.entity'));
        }
        $obj = new self(IC::adb());
        $obj->setName($attributes['name']);
        $obj->setCreatedBy(Login::currentUser()->getId());
        return $obj;
    }

    // getMoreWhere(): standard query builder
    public static function getMoreWhere($where): array
    {
        $ret = array();
        $seed = IC::adb()->rowsArray(self::TB_MY_MODEL, $where);
        foreach ($seed as $record) {
            $obj = new self(IC::adb());
            $obj->record = $record;
            $ret[] = $obj;
        }
        return $ret;
    }

    // getList(), getListByIdLocation(): always use getMoreWhere()
    public static function getList()
    {
        return self::getMoreWhere('1=1');
    }

    public static function getListByIdLocation($idLocation)
    {
        return self::getMoreWhere('id_location = ' . (int)$idLocation);
    }

    // getOneBy*(): ALWAYS returns new self() — check with getId() > 0
    public static function getOneByName($name): MyModel
    {
        $record = IC::adb()->rowsArray(self::TB_MY_MODEL,
            "name = '" . pg_escape_string(IC::adb()->getSqlResource(), $name) . "'");
        if (!empty($record)) {
            return new self(IC::adb(), (int)$record[0]->attr('id_my_model'));
        }
        return new self(IC::adb());
    }
}
```

### Key Rules
- **NEVER write raw SQL INSERT/SELECT** — always use AutoDb/AutoRecord
- `rowsArray()` takes exactly 2 params: table name and WHERE clause (ORDER BY/LIMIT go in the WHERE string)
- `getOneBy*()` NEVER returns null — always `new self(IC::adb())`
- `create()` returns the object WITHOUT storing — caller calls `->store()`
- Detail JSON: use `getDetail()`, `setDetail()`, `getDetailQuick()` pattern with merge logic

## Database

- **Table names**: snake_case, singular (`nuc`, `pulse_box`, `payment_terminal`)
- **Primary keys**: `id_[table_name]` (`id_nuc`, `id_pulse_box`)
- **Foreign keys**: `id_[reference]` (`id_location`, `id_user`)
- **Standard columns**: `status`, `type`, `detail` (jsonb), `created_at`, `created_by`, `modified_at`, `modified_by`
- **Triggers**: `SELECT create_standard_triggers('table_name');`
- **TimescaleDB**: composite PK `(id_col, created_at)`, then `SELECT create_hypertable(...)`
- **Booleans**: PostgreSQL uses `t`/`f` — set via `'t'`/`'f'` strings in setters

## Controller Pattern

```php
// index: fetch lists, render page
$args['currentPage'] = ControllerHelper::getCurrentPage('translation.key', 'short-name');
$args['listMyModel'] = MyModel::getList();
ControllerHelper::renderPage($response, 'myModel/index', $args);

// create: validate → create → store → return
if (!Helper::issetInRequest($request, array('name', 'type'))) {
    ExceptionHelper::throwEssentialInformationMissing(T::t('...'));
}
$obj = MyModel::create($attributes);
$obj->store();
ReturnHandlerBuilder::returnBuilder(TYPE_SUCCESS, SUB_TYPE_RELOAD_AJAX_CONTENT, null, 'my-model/reload/list');

// renderDetail: load object, return HTML via ReturnHandlerBuilder
ReturnHandlerBuilder::returnBuilder(TYPE_SUCCESS_NO_FEEDBACK, SUB_TYPE_REPLACE_WITH,
    array("id" => "editMyModel", "html" => MyModelTemplateRender::renderDetail($args)));

// reloadList: return updated list HTML
ReturnHandlerBuilder::returnBuilder(TYPE_JS, SUB_TYPE_REPLACE_WITH,
    array("id" => "listMyModel", "html" => MyModelTemplateRender::renderList($args)),
    null, "helper.genericDataTable();");
```

## Template Pattern

- Use `T::t('key')` for ALL strings — never hardcoded text
- Values: just `echo $obj->getValue()` — no `htmlspecialchars()` unless user-input in forms
- Form inputs: `value="<?php echo $obj->getValue(); ?>"`
- Null safety: handle in model getters with `?? ''`, not in templates
- Selects: `InnerTemplateRender::renderGenericListKeyOption(array('listOption' => ..., 'selected' => ..., 'empty' => true))`
- Status/type display: `$obj->renderStatus()`, `$obj->renderType()`

## TemplateRender Pattern

```php
class MyModelTemplateRender
{
    public static function renderNew($args = array())
    {
        return Cache::getCi()->renderer->fetch(TP::p('myModel/module/new'), $args);
    }
    public static function renderDetail($args = array())
    {
        return Cache::getCi()->renderer->fetch(TP::p('myModel/module/detail'), $args);
    }
    public static function renderList($args = array())
    {
        return Cache::getCi()->renderer->fetch(TP::p('myModel/module/list'), $args);
    }
}
```

## Translation Keys

- Format: `module.category.key` (e.g., `nuc.status.live`, `common.label.name`)
- Categories: `label`, `status`, `type`, `error`, `btn`, `help`, `system`
- Constants: `const STATUS_LIVE_TXT = 'nuc.status.live';`
- Usage: `T::t(self::STATUS_LIVE_TXT)` or `T::t('common.label.name')`

## Error Handling

- `ExceptionHelper::throwEssentialInformationMissing(T::t('...'))` — missing required fields
- `ExceptionHelper::throwDoesNotExistObj(T::t('...'))` — object not found
- `ExceptionHelper::throwAlreadyExistObj(T::t('...'))` — duplicate
- `ExceptionHelper::throwAccessDenied()` — permission denied
- Controller catch: `ControllerHelper::manageError()` or `ReturnHandlerBuilder::returnErrorBuilder()`

## Routes

- Group: `$app->group('/my-model', function () use ($app) { ... });`
- CRUD: GET `''` (index), POST `/create`, POST `/update/{id}`, POST `/detail/{id}`, POST `/reload/list`
- URL style: kebab-case (`/device-headwind`, `/pulse-box`)

## Permissions

- Constants in `App/Model/NoDb/Permission.php`
- Check: `Permission::require(Permission::MY_PERMISSION);` or `Login::currentUser()->hasPermission(Permission::MY_PERMISSION)`
- Hierarchy: `FULL` implies `READONLY`

## HTTP Client (External APIs)

- Use curl directly (no Guzzle)
- Pattern: `curl_init`, set options, `curl_exec`, check HTTP code, `curl_close`
- Log errors via `DebugLog::log()` or `SysLog::log()`

## Commands (CLI/Cron)

- Class with `command($argv)` method
- Register in `src/settings.php` under `'commands'` array
- Constructor: `__construct($ci)` with `Cache::setCi($ci)`
- Run: `cd command/v2/ && php index.php CommandName param1`

## NUC Sync Flag (`sync` column)

For a record that mirrors to the NUC via a `sync` smallint + `SyncX`/`SyncXList` command, the flag means exactly one thing:

> **`sync = 1` = the record's *current* state has been pushed to the NUC. `sync = 0` = it has not.**

That contract has **two halves — implement both**:

1. **Mark synced on a successful push.** In the `OutboundXManager::sync()`, store `sync = 1` (`sync_at`, `modified_by`) **whenever the push succeeds** — for a single-target record when `count($result['listSuccessIdNuc']) > 0`; for a two-sided record (source+destination) only when **all required** targets accepted. Nothing else gates it.
2. **Reset `sync = 0` on every change.** Any Manager/Controller that mutates a field carried in the sync payload (status transitions, line/quantity edits, amounts) calls `$x->setSync(Helper::NO)` before `store()`. This is what makes a change re-propagate, and — critically — if a push fails, the flag stays `0` so the sweeper retries. Skip it only for edits to fields the NUC never receives.

```php
// Outbound manager — mark on success, no other gate
if (count($listResult['listSuccessIdNuc']) > 0) {
    $x->setSync(Helper::YES);
    $x->setSyncAt(Helper::getNowServer());
    $x->setModifiedBy(Login::currentUser()->getId());
    $x->store();
}

// Any mutation site — flag dirty before storing
$x->setStatus(Model::STATUS_CONFIRMED);
$x->setSync(Helper::NO);
$x->store();
```

Rules:

- **Never gate `sync = 1` on the record reaching a terminal/"final" state.** A gate like `canMarkAsSynced()` (only mark synced once `closed/rejected/received`) is the classic mistake: active records then re-push to the NUC on *every* cron tick forever, because half 2 was never implemented. If you feel you need such a gate, the reset-on-change half is missing.
- **Drafts never sync.** Exclude them at the source: `getListNotSync()` adds `AND status <> STATUS_DRAFT`, plus a defensive `if ($x->isDraft()) { return true; }` guard at the top of `sync()`.
- **New records:** location-bound rows default `sync = 0` (DB default) so the command picks them up; rows with no NUC target (`!isLocation()`) are set `sync = 1` at creation, or marked synced immediately by `sync()`.
- **Immutable ledger rows** (e.g. `WarehouseStockMovement`) are the simple case: mark `sync = 1` on first successful push and never reset — there is no half 2 because the row never changes. Use it as the reference shape.
- **Two distinct NUC targets** return per-NUC results keyed by NUC id; merge them with `+` (union), not `array_merge` — `array_merge` clobbers the `listSuccessIdNuc`/`listErrorNuc` keys and loses one target's result.
