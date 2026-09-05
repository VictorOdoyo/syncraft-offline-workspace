if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/offline-sw.js').catch(error => {
      console.warn('Offline shell registration failed', error.message);
    });
  });
}
