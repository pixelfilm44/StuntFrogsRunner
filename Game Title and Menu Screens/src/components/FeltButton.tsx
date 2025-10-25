import { motion } from 'motion/react';
import { LucideIcon } from 'lucide-react';
import { ReactNode } from 'react';

interface FeltButtonProps {
  children?: ReactNode;
  icon?: LucideIcon;
  onClick?: () => void;
  variant?: 'primary' | 'secondary';
  className?: string;
  iconClassName?: string;
  isSelected?: boolean;
  gradientColor?: string;
}

export function FeltButton({
  children,
  icon: Icon,
  onClick,
  variant = 'primary',
  className = '',
  iconClassName = '',
  isSelected = false,
  gradientColor = 'from-lime-400 to-emerald-600',
}: FeltButtonProps) {
  // Generate unique organic border radius for each button instance
  const organicRadius = `${45 + Math.random() * 10}% ${55 + Math.random() * 10}% ${50 + Math.random() * 10}% ${50 + Math.random() * 10}% / ${50 + Math.random() * 10}% ${50 + Math.random() * 10}% ${45 + Math.random() * 10}% ${55 + Math.random() * 10}%`;
  
  return (
    <motion.button
      onClick={onClick}
      className={`relative overflow-visible ${className}`}
      whileHover={{ scale: 1.05, rotate: Math.random() * 4 - 2 }}
      whileTap={{ scale: 0.95 }}
      style={{
        filter: isSelected 
          ? 'drop-shadow(0 8px 16px rgba(0, 0, 0, 0.3)) drop-shadow(0 0 20px rgba(16, 185, 129, 0.4))'
          : 'drop-shadow(0 6px 12px rgba(0, 0, 0, 0.25))',
      }}
    >
      {/* Main felt shape */}
      <div
        className={`relative overflow-hidden ${
          variant === 'primary'
            ? 'bg-gradient-to-br from-lime-500 to-emerald-600'
            : 'bg-gradient-to-br from-teal-600 to-emerald-700'
        }`}
        style={{
          borderRadius: organicRadius,
          border: '3px solid rgba(255, 255, 255, 0.3)',
        }}
      >
        {/* Felt texture overlay */}
        <div
          className="absolute inset-0 opacity-20"
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
            mixBlendMode: 'overlay',
          }}
        />
        
        {/* Color highlight on hover */}
        {isSelected && (
          <motion.div
            className={`absolute inset-0 bg-gradient-to-r ${gradientColor} opacity-30`}
            initial={{ opacity: 0 }}
            animate={{ opacity: 0.3 }}
            transition={{ duration: 0.3 }}
          />
        )}
        
        {/* Content */}
        <div className="relative z-10 flex items-center justify-center gap-3 px-6 py-4 sm:gap-4 sm:px-8 sm:py-5">
          {Icon && (
            <motion.div
              animate={isSelected ? { rotate: 360, scale: 1.1 } : { rotate: 0, scale: 1 }}
              transition={{ duration: 0.5, type: 'spring' }}
            >
              <Icon className={`text-white ${iconClassName}`} />
            </motion.div>
          )}
          {children && (
            <span className="text-white drop-shadow-md">{children}</span>
          )}
        </div>
        
        {/* Decorative stitching effect */}
        <div
          className="absolute inset-0 pointer-events-none"
          style={{
            borderRadius: organicRadius,
            border: '2px dashed rgba(255, 255, 255, 0.15)',
            margin: '6px',
          }}
        />
      </div>
    </motion.button>
  );
}
