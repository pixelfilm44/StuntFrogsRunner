import { motion } from 'motion/react';
import { Pause, Heart, Droplet, Bug, LifeBuoy, Axe } from 'lucide-react';
import { FeltButton } from './FeltButton';
import { useState } from 'react';

interface PlayScreenProps {
  onPause: () => void;
}

interface ItemCountProps {
  icon: React.ElementType;
  count: number;
  maxCount: number;
  color: string;
}

function ItemCount({ icon: Icon, count, maxCount, color }: ItemCountProps) {
  return (
    <div className="flex flex-wrap gap-1">
      {[...Array(maxCount)].map((_, i) => {
        const isActive = i < count;
        const organicRadius = `${45 + Math.random() * 10}% ${55 + Math.random() * 10}% ${50 + Math.random() * 10}% ${50 + Math.random() * 10}% / ${50 + Math.random() * 10}% ${50 + Math.random() * 10}% ${45 + Math.random() * 10}% ${55 + Math.random() * 10}%`;
        
        return (
          <motion.div
            key={i}
            className="relative"
            initial={{ scale: 0, rotate: Math.random() * 360 }}
            animate={{ scale: 1, rotate: 0 }}
            transition={{ delay: i * 0.05, type: 'spring' }}
            style={{
              filter: isActive 
                ? 'drop-shadow(0 2px 4px rgba(0, 0, 0, 0.25))'
                : 'drop-shadow(0 1px 2px rgba(0, 0, 0, 0.15))',
            }}
          >
            <div
              className={`p-1.5 sm:p-2 ${
                isActive ? color : 'bg-gray-600/50'
              }`}
              style={{
                borderRadius: organicRadius,
                border: `2px solid ${isActive ? 'rgba(255, 255, 255, 0.4)' : 'rgba(255, 255, 255, 0.2)'}`,
                opacity: isActive ? 1 : 0.4,
              }}
            >
              {/* Texture overlay */}
              <div
                className="absolute inset-0 opacity-20"
                style={{
                  backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
                  borderRadius: 'inherit',
                  mixBlendMode: 'overlay',
                }}
              />
              <Icon 
                className={`relative z-10 h-4 w-4 sm:h-5 sm:w-5 ${
                  isActive ? 'text-white' : 'text-gray-400'
                }`}
              />
            </div>
          </motion.div>
        );
      })}
    </div>
  );
}

export function PlayScreen({ onPause }: PlayScreenProps) {
  const [score] = useState(12450);
  const [hearts] = useState(5);
  const [honeyJars] = useState(4);
  const [flySwatters] = useState(3);
  const [lifeVests] = useState(6);
  const [axes] = useState(2);

  return (
    <div className="relative h-screen w-full overflow-hidden bg-gradient-to-br from-emerald-600 via-teal-500 to-cyan-400">
      {/* Paper texture overlay */}
      <div 
        className="absolute inset-0 opacity-10"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
        }}
      />

      {/* Animated background elements */}
      <div className="absolute inset-0">
        {[...Array(8)].map((_, i) => {
          const organicRadius = `${40 + Math.random() * 20}% ${60 + Math.random() * 20}% ${50 + Math.random() * 15}% ${50 + Math.random() * 15}% / ${50 + Math.random() * 15}% ${50 + Math.random() * 15}% ${40 + Math.random() * 20}% ${60 + Math.random() * 20}%`;
          return (
            <motion.div
              key={i}
              className="absolute bg-lime-300/10"
              style={{
                width: Math.random() * 120 + 40,
                height: Math.random() * 120 + 40,
                left: `${Math.random() * 100}%`,
                top: `${Math.random() * 100}%`,
                borderRadius: organicRadius,
                filter: 'blur(12px)',
              }}
              animate={{
                y: [0, -40, 0],
                x: [0, Math.random() * 20 - 10, 0],
                opacity: [0.1, 0.3, 0.1],
              }}
              transition={{
                duration: Math.random() * 4 + 3,
                repeat: Infinity,
                delay: Math.random() * 2,
              }}
            />
          );
        })}
      </div>

      {/* Top HUD */}
      <div className="relative z-10 flex items-start justify-between p-4 sm:p-6">
        {/* Score - Top Left */}
        <motion.div
          initial={{ x: -100, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 100 }}
          style={{
            filter: 'drop-shadow(0 6px 12px rgba(0, 0, 0, 0.3))',
          }}
        >
          <div
            className="bg-gradient-to-br from-yellow-500 to-orange-600 px-4 py-2 sm:px-6 sm:py-3"
            style={{
              borderRadius: '48% 52% 50% 50% / 55% 50% 50% 45%',
              border: '3px solid rgba(255, 255, 255, 0.4)',
            }}
          >
            {/* Texture overlay */}
            <div
              className="absolute inset-0 opacity-20"
              style={{
                backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
                borderRadius: 'inherit',
                mixBlendMode: 'overlay',
              }}
            />
            <div className="relative z-10">
              <p className="text-white/80 drop-shadow-md">Score</p>
              <motion.p 
                className="text-white drop-shadow-lg"
                key={score}
                initial={{ scale: 1.2 }}
                animate={{ scale: 1 }}
              >
                {score.toLocaleString()}
              </motion.p>
            </div>
          </div>
        </motion.div>

        {/* Pause Button - Top Right */}
        <motion.div
          initial={{ x: 100, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 100 }}
        >
          <FeltButton
            icon={Pause}
            onClick={onPause}
            variant="secondary"
            iconClassName="h-6 w-6 sm:h-8 sm:w-8"
          />
        </motion.div>
      </div>

      {/* Main Game Area */}
      <div className="relative z-10 flex h-[calc(100vh-280px)] items-center justify-center sm:h-[calc(100vh-320px)]">
        <motion.div
          className="text-white/60 text-center px-4"
          animate={{ opacity: [0.3, 0.6, 0.3] }}
          transition={{ duration: 2, repeat: Infinity }}
        >
          <p className="drop-shadow-md">Game area - Frog jumps here!</p>
        </motion.div>
      </div>

      {/* Bottom HUD */}
      <motion.div
        className="absolute bottom-0 left-0 right-0 z-20 p-3 sm:p-4"
        initial={{ y: 100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ type: 'spring', stiffness: 100, delay: 0.2 }}
      >
        <div
          className="mx-auto max-w-3xl bg-gradient-to-br from-teal-700/90 to-emerald-800/90 p-3 backdrop-blur-sm sm:p-4"
          style={{
            borderRadius: '42% 58% 45% 55% / 48% 52% 48% 52%',
            border: '3px solid rgba(255, 255, 255, 0.3)',
            filter: 'drop-shadow(0 -4px 12px rgba(0, 0, 0, 0.4))',
          }}
        >
          {/* Texture overlay */}
          <div
            className="absolute inset-0 opacity-15"
            style={{
              backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
              borderRadius: 'inherit',
              mixBlendMode: 'overlay',
            }}
          />

          <div className="relative z-10 space-y-3 sm:space-y-4">
            {/* Top Row - Hearts (Health) */}
            <div className="flex justify-center">
              <ItemCount
                icon={Heart}
                count={hearts}
                maxCount={6}
                color="bg-gradient-to-br from-red-500 to-rose-600"
              />
            </div>

            {/* Bottom Row - Two Columns */}
            <div className="grid grid-cols-2 gap-3 sm:gap-4">
              {/* Left Column */}
              <div className="space-y-2 sm:space-y-3">
                {/* Honey Jars */}
                <div className="flex justify-center sm:justify-end">
                  <ItemCount
                    icon={Droplet}
                    count={honeyJars}
                    maxCount={4}
                    color="bg-gradient-to-br from-amber-500 to-yellow-600"
                  />
                </div>
                {/* Fly Swatters */}
                <div className="flex justify-center sm:justify-end">
                  <ItemCount
                    icon={Bug}
                    count={flySwatters}
                    maxCount={4}
                    color="bg-gradient-to-br from-purple-500 to-violet-600"
                  />
                </div>
              </div>

              {/* Right Column */}
              <div className="space-y-2 sm:space-y-3">
                {/* Life Vests */}
                <div className="flex justify-center sm:justify-start">
                  <ItemCount
                    icon={LifeBuoy}
                    count={lifeVests}
                    maxCount={4}
                    color="bg-gradient-to-br from-blue-500 to-cyan-600"
                  />
                </div>
                {/* Axes */}
                <div className="flex justify-center sm:justify-start">
                  <ItemCount
                    icon={Axe}
                    count={axes}
                    maxCount={4}
                    color="bg-gradient-to-br from-slate-500 to-gray-600"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
