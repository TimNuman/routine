import { Stack } from 'expo-router';
import { useFonts } from 'expo-font';
// Bijgeknipt tot Latijn door lettertypes.mjs; de originelen van Google hebben
// er Devanagari en Cyrillisch bij zitten en zijn zeven keer zo groot.
import Baloo2_700Bold from '../assets/fonts/Baloo2_700Bold.ttf';
import Baloo2_800ExtraBold from '../assets/fonts/Baloo2_800ExtraBold.ttf';
import Nunito_700Bold from '../assets/fonts/Nunito_700Bold.ttf';
import Nunito_800ExtraBold from '../assets/fonts/Nunito_800ExtraBold.ttf';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { Gezinshuis } from '../onderdelen/gezin';
import '../global.css';

export default function Indeling() {
  const [klaar] = useFonts({
    Baloo2_700Bold, Baloo2_800ExtraBold, Nunito_700Bold, Nunito_800ExtraBold,
  });
  if (!klaar) return null;
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <StatusBar style="dark" />
        <Gezinshuis>
          {/* Van tabblad wisselen is geen reis: geen schuif, geen vervaging. */}
          <Stack screenOptions={{ headerShown: false, animation: 'none',
                                  contentStyle: { backgroundColor: 'transparent' } }} />
        </Gezinshuis>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
