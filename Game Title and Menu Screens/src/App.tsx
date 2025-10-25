import { useState } from 'react';
import { TitleScreen } from './components/TitleScreen';
import { MenuScreen } from './components/MenuScreen';
import { PlayScreen } from './components/PlayScreen';
import { motion, AnimatePresence } from 'motion/react';

type Screen = 'title' | 'menu' | 'play';

export default function App() {
  const [currentScreen, setCurrentScreen] = useState<Screen>('title');

  const handlePlayGame = () => {
    setCurrentScreen('play');
  };

  const handlePause = () => {
    setCurrentScreen('menu');
  };

  return (
    <div className="h-screen w-full overflow-hidden">
      <AnimatePresence mode="wait">
        {currentScreen === 'title' && (
          <motion.div
            key="title"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0, scale: 0.8 }}
            transition={{ duration: 0.5 }}
          >
            <TitleScreen onStart={() => setCurrentScreen('menu')} />
          </motion.div>
        )}
        
        {currentScreen === 'menu' && (
          <motion.div
            key="menu"
            initial={{ opacity: 0, scale: 1.2 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.5 }}
          >
            <MenuScreen onBack={() => setCurrentScreen('title')} onPlayGame={handlePlayGame} />
          </motion.div>
        )}

        {currentScreen === 'play' && (
          <motion.div
            key="play"
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -50 }}
            transition={{ duration: 0.5 }}
          >
            <PlayScreen onPause={handlePause} />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
