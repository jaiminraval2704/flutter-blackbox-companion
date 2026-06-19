{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Hide the loader gracefully
    const loadingEl = document.getElementById('loading');
    if (loadingEl) {
      loadingEl.style.opacity = '0';
      setTimeout(() => {
        loadingEl.remove();
      }, 500); // Wait for transition to finish
    }
    
    await appRunner.runApp();
  }
});
