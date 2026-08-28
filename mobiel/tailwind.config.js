/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{js,jsx,ts,tsx}', './onderdelen/**/*.{js,jsx,ts,tsx}'],
  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      colors: {
        inkt: '#2B2D42',
        'inkt-zacht': '#5C5F7A',
        oranje: '#F2994A',
        'oranje-diep': '#D97B2B',
        room: '#FFF9EF',
        rood: '#E5484D',
      },
      fontFamily: {
        rond: ['Baloo2_800ExtraBold'],
        rondje: ['Baloo2_700Bold'],
        tekst: ['Nunito_700Bold'],
        tekstdik: ['Nunito_800ExtraBold'],
      },
    },
  },
  plugins: [],
};
