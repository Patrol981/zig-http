<script lang="ts">
  import Icon from "@iconify/svelte";
</script>

<div class="navbar">
  <div class="nav-item">
    <Icon icon="mdi:calendar" style="font-size: 2.5em;" />
  </div>
  <div class="nav-item">
    <Icon icon="mdi:person" style="font-size: 2.5em;" />
  </div>
  <div class="nav-item">
    <Icon icon="mdi:view-list" style="font-size: 2.5em;" />
  </div>
  <div class="nav-item">
    <Icon icon="mdi:logout" style="font-size: 2.5em;" />
  </div>
</div>

<style lang="scss" scoped>
  .navbar {
    height: 100%;
    width: 5em;

    background-color: #1b263b;
    color: #e0e1dd;

    display: flex;
    flex-direction: column;

    justify-content: flex-start;
    align-content: flex-start;

    justify-items: center;
    align-items: center;

    .nav-item {
      background-color: #415a77;
      border-radius: 15px;

      height: 4em;
      width: 4em;

      display: flex;
      flex-direction: column;

      vertical-align: middle;
      justify-content: center;
      align-content: center;

      align-items: center;
      justify-items: center;

      text-align: center;
      user-select: none;

      margin-top: 1em;

      transition: all 50ms ease-in;
    }
  }
</style>
