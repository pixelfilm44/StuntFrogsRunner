import { motion } from 'motion/react';
import { Play, Settings, Trophy, LogOut, Volume2, User } from 'lucide-react';
import { FeltButton } from './FeltButton';
import { useState } from 'react';

interface MenuScreenProps {
  onBack: () => void;
  onPlayGame: () => void;
}

export function MenuScreen({ onBack, onPlayGame }: MenuScreenProps) {
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  // Reduce orbs on mobile for better performance
  const orbCount = typeof window !== 'undefined' && window.innerWidth < 640 ? 4 : 8;

  const menuItems = [
    { icon: Play, label: 'Play Game', color: 'from-lime-400 to-emerald-600' },
    { icon: User, label: 'Profile', color: 'from-cyan-400 to-blue-600' },
    { icon: Trophy, label: 'Leaderboard', color: 'from-red-400 to-orange-600' },
    { icon: Settings, label: 'Settings', color: 'from-teal-400 to-emerald-600' },
    { icon: Volume2, label: 'Audio', color: 'from-blue-400 to-indigo-600' },
    { icon: LogOut, label: 'Exit', color: 'from-slate-400 to-slate-600' },
  ];

  return (
    <div className="relative h-screen w-full overflow-hidden bg-gradient-to-br from-teal-900 via-emerald-900 to-cyan-900">
      {/* Paper/canvas texture overlay */}
      <div 
        className="absolute inset-0 opacity-10"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
        }}
      />
      
      {/* Animated grid background */}
      <div className="absolute inset-0 opacity-10">
        <div className="h-full w-full" style={{
          backgroundImage: 'linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)',
          backgroundSize: '50px 50px',
        }} />
      </div>

      {/* Floating swamp orbs - organic felt shapes */}
      {[...Array(orbCount)].map((_, i) => {
        const organicRadius = `${40 + Math.random() * 20}% ${60 + Math.random() * 20}% ${50 + Math.random() * 15}% ${50 + Math.random() * 15}% / ${50 + Math.random() * 15}% ${50 + Math.random() * 15}% ${40 + Math.random() * 20}% ${60 + Math.random() * 20}%`;
        return (
          <motion.div
            key={i}
            className="absolute"
            style={{
              width: Math.random() * 150 + 50,
              height: Math.random() * 150 + 50,
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
              background: `radial-gradient(circle, ${
                ['rgba(16, 185, 129, 0.25)', 'rgba(6, 182, 212, 0.25)', 'rgba(52, 211, 153, 0.25)'][i % 3]
              }, transparent)`,
              borderRadius: organicRadius,
              filter: 'blur(20px)',
            }}
            animate={{
              x: [0, Math.random() * 100 - 50],
              y: [0, Math.random() * 100 - 50],
            }}
            transition={{
              duration: Math.random() * 10 + 10,
              repeat: Infinity,
              repeatType: 'reverse',
            }}
          />
        );
      })}

      {/* Content */}
      <div className="relative z-10 flex h-full flex-col items-center justify-center gap-6 p-4 sm:gap-12 sm:p-8">
        {/* Title - Felt badge style */}
        <motion.div
          initial={{ y: -50, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 100 }}
          className="relative"
          style={{
            filter: 'drop-shadow(0 6px 12px rgba(0, 0, 0, 0.3))',
          }}
        >
          <div
            className="bg-gradient-to-br from-teal-600 to-emerald-700 px-8 py-4 sm:px-12 sm:py-5"
            style={{
              borderRadius: '45% 55% 52% 48% / 48% 52% 48% 52%',
              border: '3px solid rgba(255, 255, 255, 0.3)',
            }}
          >
            <div
              className="absolute inset-0 opacity-20"
              style={{
                backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
                borderRadius: 'inherit',
                mixBlendMode: 'overlay',
              }}
            />
            <h2 className="relative z-10 text-white text-center drop-shadow-md">
              MAIN MENU
            </h2>
          </div>
        </motion.div>

        {/* Menu Items - Felt buttons */}
        <div className="grid w-full max-w-md gap-4 sm:max-w-2xl sm:grid-cols-2 sm:gap-5">
          {menuItems.map((item, index) => {
            const Icon = item.icon;
            return (
              <motion.div
                key={index}
                initial={{ opacity: 0, x: index % 2 === 0 ? -50 : 50 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.1 }}
                onHoverStart={() => setSelectedIndex(index)}
                onHoverEnd={() => setSelectedIndex(null)}
                onTouchStart={() => setSelectedIndex(index)}
              >
                <FeltButton
                  icon={Icon}
                  onClick={() => {
                    if (item.label === 'Exit') {
                      onBack();
                    } else if (item.label === 'Play Game') {
                      onPlayGame();
                    } else {
                      console.log(`Selected: ${item.label}`);
                    }
                  }}
                  variant="secondary"
                  className="w-full"
                  iconClassName="h-6 w-6 sm:h-8 sm:w-8"
                  isSelected={selectedIndex === index}
                  gradientColor={item.color}
                >
                  {item.label}
                </FeltButton>
              </motion.div>
            );
          })}
        </div>

        {/* Footer info */}
        <motion.div
          className="absolute bottom-6 px-4 text-white/60 text-center sm:bottom-8"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
        >
          <p className="hidden sm:block">Use your mouse to select an option</p>
          <p className="sm:hidden">Tap to select an option</p>
        </motion.div>
      </div>
    </div>
  );
}
