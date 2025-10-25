import { motion } from 'motion/react';
import { Zap } from 'lucide-react';
import { FeltButton } from './FeltButton';

interface TitleScreenProps {
  onStart: () => void;
}

export function TitleScreen({ onStart }: TitleScreenProps) {
  // Reduce particles on mobile for better performance
  const particleCount = typeof window !== 'undefined' && window.innerWidth < 640 ? 10 : 20;
  
  return (
    <div className="relative h-screen w-full overflow-hidden bg-gradient-to-br from-emerald-600 via-teal-500 to-cyan-400">
      {/* Paper texture overlay */}
      <div 
        className="absolute inset-0 opacity-10"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
        }}
      />
      
      {/* Animated background lily pads / water droplets */}
      <div className="absolute inset-0">
        {[...Array(particleCount)].map((_, i) => {
          const organicRadius = `${40 + Math.random() * 20}% ${60 + Math.random() * 20}% ${50 + Math.random() * 15}% ${50 + Math.random() * 15}% / ${50 + Math.random() * 15}% ${50 + Math.random() * 15}% ${40 + Math.random() * 20}% ${60 + Math.random() * 20}%`;
          return (
            <motion.div
              key={i}
              className="absolute bg-lime-300/20"
              style={{
                width: Math.random() * 100 + 20,
                height: Math.random() * 100 + 20,
                left: `${Math.random() * 100}%`,
                top: `${Math.random() * 100}%`,
                borderRadius: organicRadius,
                filter: 'blur(8px)',
              }}
              animate={{
                y: [0, -30, 0],
                opacity: [0.2, 0.5, 0.2],
                scale: [1, 1.1, 1],
              }}
              transition={{
                duration: Math.random() * 3 + 2,
                repeat: Infinity,
                delay: Math.random() * 2,
              }}
            />
          );
        })}
      </div>

      {/* Content */}
      <div className="relative z-10 flex h-full flex-col items-center justify-center gap-6 px-4 sm:gap-12">
        {/* Title */}
        <motion.div
          className="flex flex-col items-center gap-4 sm:gap-6"
          initial={{ scale: 0, rotate: -180 }}
          animate={{ scale: 1, rotate: 0 }}
          transition={{ type: 'spring', duration: 1, delay: 0.2 }}
        >
          {/* Felt badge for icon */}
          <motion.div
            className="relative"
            animate={{ 
              rotate: [0, 5, -5, 0],
              y: [0, -8, 0]
            }}
            transition={{ duration: 1.2, repeat: Infinity }}
            style={{
              filter: 'drop-shadow(0 8px 16px rgba(0, 0, 0, 0.3))',
            }}
          >
            <div
              className="relative bg-gradient-to-br from-red-500 to-orange-600 p-4 sm:p-6"
              style={{
                borderRadius: '48% 52% 51% 49% / 53% 47% 53% 47%',
                border: '4px solid rgba(255, 255, 255, 0.4)',
              }}
            >
              {/* Texture overlay */}
              <div
                className="absolute inset-0 opacity-30"
                style={{
                  backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
                  borderRadius: 'inherit',
                  mixBlendMode: 'overlay',
                }}
              />
              <Zap className="relative z-10 h-12 w-12 text-yellow-100 sm:h-16 sm:w-16" fill="currentColor" />
            </div>
          </motion.div>
          
          <h1 className="text-white text-center px-4 drop-shadow-lg" style={{ 
            textShadow: '3px 3px 0 rgba(0, 0, 0, 0.2), 6px 6px 12px rgba(0, 0, 0, 0.3)'
          }}>
            STUNT FROG
          </h1>
          
          {/* Organic divider */}
          <motion.div
            className="h-2 w-48 bg-gradient-to-r from-lime-400 via-emerald-400 to-cyan-400 sm:w-64"
            style={{
              borderRadius: '50% 50% 50% 50% / 60% 60% 40% 40%',
              filter: 'drop-shadow(0 2px 4px rgba(0, 0, 0, 0.2))',
            }}
            animate={{ scaleX: [0.9, 1, 0.9] }}
            transition={{ duration: 2, repeat: Infinity }}
          />
        </motion.div>

        {/* Press Start Button - Felt style */}
        <motion.div
          initial={{ opacity: 0, y: 50 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
        >
          <FeltButton onClick={onStart} variant="primary">
            PRESS START
          </FeltButton>
        </motion.div>

        {/* Pulsing indicator */}
        <motion.div
          className="absolute bottom-8 px-4 sm:bottom-12"
          animate={{ opacity: [0.3, 1, 0.3] }}
          transition={{ duration: 2, repeat: Infinity }}
        >
          <p className="text-white/80 text-center">Tap to begin</p>
        </motion.div>
      </div>
    </div>
  );
}
