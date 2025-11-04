//
//  SoundSettingsView.swift
//  Complete Top-down lily pad hopping game
//  Sound settings interface for controlling audio preferences
//

import SwiftUI

struct SoundSettingsView: View {
    @ObservedObject private var soundController = SoundController.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Music")) {
                    Toggle("Enable Music", isOn: $soundController.isMusicEnabled)
                    
                    if soundController.isMusicEnabled {
                        VStack {
                            HStack {
                                Text("Music Volume")
                                Spacer()
                                Text("\(Int(soundController.musicVolume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $soundController.musicVolume, in: 0...1, step: 0.1)
                                .accentColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Sound Effects")) {
                    Toggle("Enable Sound Effects", isOn: $soundController.areSoundEffectsEnabled)
                    
                    if soundController.areSoundEffectsEnabled {
                        VStack {
                            HStack {
                                Text("Effects Volume")
                                Spacer()
                                Text("\(Int(soundController.soundEffectsVolume * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $soundController.soundEffectsVolume, in: 0...1, step: 0.1)
                                .accentColor(.green)
                        }
                    }
                }
                
                Section(header: Text("Test Sounds")) {
                    Button("Test Frog Jump") {
                        soundController.playFrogJumpSound(intensity: 0.8)
                    }
                    
                    Button("Test Splash") {
                        soundController.playWaterSplash(severity: 1.0)
                    }
                    
                    Button("Test Button Sound") {
                        soundController.playSoundEffect(.buttonTap)
                    }
                    
                    Button("Test Collect Sound") {
                        soundController.playCollectSound()
                    }
                }
                
                Section {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        soundController.saveUserPreferences()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func resetToDefaults() {
        soundController.isMusicEnabled = true
        soundController.areSoundEffectsEnabled = true
        soundController.musicVolume = 0.7
        soundController.soundEffectsVolume = 0.8
    }
}

// Preview for SwiftUI canvas
#Preview {
    SoundSettingsView()
}