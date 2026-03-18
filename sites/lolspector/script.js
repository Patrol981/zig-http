document.addEventListener('alpine:init', () => {
  Alpine.data('partial', (url) => ({
    html: '',
    async init() {
      await this.loadPage(url);

      this.$watch('$store.current_route', async (next) => {
        await this.loadPage(next);
      })
    },

    async loadPage(url) {
      this.html = await fetch(url, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'fetch-partial'
        }
      }).then(r => r.text());
    }
  }))

  Alpine.data('navbar', (url) => ({
    html: '',
    async init() {
      this.html = await fetch(url, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'fetch-partial'
        }
      }).then(r => r.text());
    }
  }))

  Alpine.data('clash', () => ({
    clash_schedules: [],
    clash_infos: [],

    async init() {
      console.log('[clash] init component');

      const data = await fetch("http://localhost:8000/clash/schedule");
      const json = await data.json();

      this.clash_schedules = json;
      this.clash_infos = getTournamentInfo(json);
      console.log(this.clash_schedules);
      console.log(this.clash_infos);
    }
  }));

  Alpine.store('current_route', 'clash.html')
});
