export function weatherAttributionMarkup({ compact = false } = {}) {
  return `
    <span class="weather-credit__source">Weather data by
      <a href="https://open-meteo.com/" target="_blank" rel="noopener noreferrer">Open-Meteo</a>
      · <a href="https://creativecommons.org/licenses/by/4.0/" target="_blank" rel="noopener noreferrer">CC BY 4.0</a>
    </span>
    ${compact ? "" : '<span class="weather-credit__note">Forecast summaries and ratings adapted for stargazing.</span>'}
  `;
}

export function initializeWeatherCredits() {
  document.querySelectorAll("[data-weather-credit]").forEach((element) => {
    element.innerHTML = weatherAttributionMarkup();
  });
}
