import { Stack } from 'expo-router';
import { useFonts } from 'expo-font';
// Per gewicht importeren, niet via de pakket-index: anders bundelt Metro alle
// gewichten van beide families mee — dat scheelde 4 MB.
import Baloo2_700Bold from '@expo-google-fonts/baloo-2/700Bold/Baloo2_700Bold.ttf';
import Baloo2_800ExtraBold from '@expo-google-fonts/baloo-2/800ExtraBold/Baloo2_800ExtraBold.ttf';
import Nunito_700Bold from '@expo-google-fonts/nunito/700Bold/Nunito_700Bold.ttf';
import Nunito_800ExtraBold from '@expo-google-fonts/nunito/800ExtraBold/Nunito_800ExtraBold.ttf';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
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
        <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: 'transparent' } }} />
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
