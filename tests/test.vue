<template>
  <span
    :class="`${ 
      containerClass + 1231111111111111111111111111111111111111111111111111111111111111111111111
    }`"
    v-bind="$attrs">
    <slot>
      <span class="p-tag-value">
        {{ 
          (function (foo, bar) {
            return 1;
            foo();
            1 + 2;
            let x = 1;
          })()
        }}
      </span>
    </slot>
  </span>
</template>
<script lang="ts">
import { defineComponent } from "vue";
export default defineComponent({});

</script>
<style>
.p-tag {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 6;
}
</style>
