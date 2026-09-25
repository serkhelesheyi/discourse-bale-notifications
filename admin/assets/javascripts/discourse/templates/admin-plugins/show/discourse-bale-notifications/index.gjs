import DButton from "discourse/components/d-button";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";

<template>
  <div class="bale-notifications-admin">
    <h3>{{i18n "bale-notifications.admin.title"}}</h3>

    <div class="bale-admin-summary">
      <div class="bale-admin-stat">
        <span class="bale-admin-stat-number">
          {{@controller.model.linked_users_count}}
        </span>
        <span class="bale-admin-stat-label">
          {{i18n "bale-notifications.admin.linked_users"}}
        </span>
      </div>

      <div class="bale-admin-stat">
        <span class="bale-admin-stat-number">
          {{if
            @controller.model.enabled
            (i18n "bale-notifications.admin.enabled")
            (i18n "bale-notifications.admin.disabled")
          }}
        </span>

        <span class="bale-admin-stat-label">
          {{i18n "bale-notifications.admin.status"}}
        </span>
      </div>
    </div>

    <h4>{{i18n "bale-notifications.admin.webhook_status"}}</h4>

    {{#if @controller.model.webhook_info.result}}
      <table class="bale-admin-table">
        <tbody>
          <tr>
            <td>
              {{i18n "bale-notifications.admin.webhook_url"}}
            </td>
            <td>
              {{@controller.model.webhook_info.result.url}}
            </td>
          </tr>

          <tr>
            <td>
              {{i18n "bale-notifications.admin.webhook_pending"}}
            </td>
            <td>
              {{@controller.model.webhook_info.result.pending_update_count}}
            </td>
          </tr>

          {{#if @controller.model.webhook_info.result.last_error_message}}
            <tr>
              <td>
                {{i18n "bale-notifications.admin.webhook_last_error"}}
              </td>
              <td>
                {{@controller.model.webhook_info.result.last_error_message}}
              </td>
            </tr>
          {{/if}}
        </tbody>
      </table>
    {{else}}
      <p class="bale-admin-warning">
        {{i18n "bale-notifications.admin.webhook_unreachable"}}
      </p>
    {{/if}}

    <h4>{{i18n "bale-notifications.admin.send_test"}}</h4>

    <div class="bale-admin-test-form">
      <input
        type="text"
        value={{@controller.testUsername}}
        placeholder={{i18n
          "bale-notifications.admin.username_placeholder"
        }}
        {{on "input" @controller.updateTestUsername}}
      />

      <DButton
        @action={{@controller.sendTest}}
        @disabled={{@controller.testing}}
        @label="bale-notifications.admin.send_test_button"
      />

      {{#if @controller.testSucceeded}}
        <span class="bale-admin-test-ok">
          {{i18n "bale-notifications.admin.test_sent"}}
        </span>
      {{/if}}

      {{#if @controller.testFailed}}
        <span class="bale-admin-test-fail">
          {{i18n "bale-notifications.admin.test_failed_inline"}}
        </span>
      {{/if}}
    </div>

    <h4>{{i18n "bale-notifications.admin.recent_activity"}}</h4>

    {{#if @controller.model.recent_activity.length}}
      <table class="bale-admin-table bale-admin-activity">
        <thead>
          <tr>
            <th>
              {{i18n "bale-notifications.admin.activity_time"}}
            </th>
            <th>
              {{i18n "bale-notifications.admin.activity_user"}}
            </th>
            <th>
              {{i18n "bale-notifications.admin.activity_status"}}
            </th>
            <th>
              {{i18n "bale-notifications.admin.activity_error"}}
            </th>
          </tr>
        </thead>

        <tbody>
          {{#each @controller.model.recent_activity as |entry|}}
            <tr
              class={{if
                entry.ok
                "bale-activity-ok"
                "bale-activity-fail"
              }}
            >
              <td>{{entry.ts}}</td>

              <td>
                {{if entry.username entry.username "—"}}
              </td>

              <td>
                {{if
                  entry.ok
                  (i18n "bale-notifications.admin.ok")
                  (i18n "bale-notifications.admin.failed")
                }}
              </td>

              <td>{{entry.description}}</td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <p>
        {{i18n "bale-notifications.admin.no_activity"}}
      </p>
    {{/if}}
  </div>
</template>
