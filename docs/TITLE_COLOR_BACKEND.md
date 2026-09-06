# Title & Description Color — Backend Spec

The app lets an author choose a **color for the news title** and a **color for
the description**. This document is the full contract the backend must
implement. The Flutter side is already done.

---

## 1. The fields

| Property | Title | Description |
|---|---|---|
| Field name | `title_color` | `content_color` |
| Type | string | string |
| Format | `#RRGGBB` (uppercase hex, leading `#`, 6 hex digits, e.g. `#FF3366`) | same |
| Optional? | Yes | Yes |
| "No color" | Sent as an **empty string** `""` → store as `NULL` | same |
| Location in response | **Either** top-level **or** inside each `translation`. App accepts both. | same |

> The app reads each color from the translation first, then falls back to a
> top-level value. So the backend can return them in **whichever place is
> easier** — both work with no frontend change. `content_color` is the
> description's color (stored alongside `content`/`short_description`).

> The app may also accept `#AARRGGBB` (8 digits) if you ever store alpha, but it
> only ever **sends** 6-digit `#RRGGBB`.

---

## 2. What the app SENDS

Both endpoints are **multipart/form-data** (same as today's news create/update).

- **Create:** `POST /api/news`
- **Update:** `POST /api/news/{id}`

Two new form fields are **always included**:

```
title_color   = "#FF3366"   // chosen title color   (""  = no color / clear it)
content_color = "#0EA5E9"   // chosen description color ("" = no color / clear it)
```

- Non-empty → save that hex.
- Empty string `""` → save `NULL` (this is how the author removes a color on edit).

---

## 3. Database

Add a nullable `title_color` column wherever it's easiest — on `news`
(top-level) or on `news_translations` (next to `title`). Either works for the
app.

```php
// migration (pick the table you'll store/return them on)
$table->string('title_color', 9)->nullable();   // "#RRGGBB" (room for "#AARRGGBB")
$table->string('content_color', 9)->nullable();
```

Add both `title_color` and `content_color` to that model's `$fillable`.

---

## 4. Validation (store + update FormRequest / validator)

Allow null **or** empty **or** a valid hex (same rule for both):

```php
$hex = ['nullable', 'string', 'regex:/^(#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8}))?$/'];
'title_color'   => $hex,
'content_color' => $hex,
```

(The `?` makes the whole pattern optional, so an empty string passes validation.)

---

## 5. Controller (store + update)

Coerce empty string to `null` so "clear color" works (do for both fields):

```php
foreach (['title_color', 'content_color'] as $key) {
    $raw = $request->input($key);
    $model->{$key} = ($raw === null || $raw === '') ? null : $raw;
}
$model->save();
```

---

## 6. Response — RETURN them everywhere news is serialized

The app reads both colors. Add them to BOTH:

- **List:** `GET /api/news`
- **Single article** (whatever your detail/show payload is)

```json
{
  "id": 123,
  "title": "Heavy rain expected today",
  "title_color": "#FF3366",
  "short_description": "...",
  "content": "...",
  "content_color": "#0EA5E9",
  "...": "..."
}
```

- When no color is set, return `null` (or omit it — the app treats both as
  "no color" and falls back to the default theme color).

---

## 7. Summary checklist

- [ ] `title_color` + `content_color` nullable columns (migration)
- [ ] both in `$fillable`
- [ ] Validation accepts null / empty / `#RRGGBB` for both
- [ ] Store on create; empty string → `NULL`
- [ ] Update on edit; empty string → `NULL` (enables clearing)
- [ ] Return `title_color` + `content_color` in list response
- [ ] Return `title_color` + `content_color` in single-article response

That's the entire contract. No other endpoints or fields change.
