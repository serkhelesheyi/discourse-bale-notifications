import { Input } from "@ember/component";
import { i18n } from "discourse-i18n";

<template>
  <div class="control-group signatures">
    <label class="control-label">{{i18n
        "telegram-notifications.preferences-title"
      }}</label>
    <div class="controls">
      <label class="text-label">
        <Input @type="text" @value={{@model.custom_fields.telegram_chat_id}} />
      </label>
    </div>
    <div class="instructions">{{i18n
        "telegram-notifications.instructions"
      }}</div>
  </div>
</template>
