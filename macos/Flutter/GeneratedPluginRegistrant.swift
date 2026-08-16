//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_analyzer
import audioplayers_darwin
import metronome
import record_darwin
import share_plus
import video_player_avfoundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioAnalyzerPlugin.register(with: registry.registrar(forPlugin: "AudioAnalyzerPlugin"))
  AudioplayersDarwinPlugin.register(with: registry.registrar(forPlugin: "AudioplayersDarwinPlugin"))
  MetronomePlugin.register(with: registry.registrar(forPlugin: "MetronomePlugin"))
  RecordPlugin.register(with: registry.registrar(forPlugin: "RecordPlugin"))
  SharePlusMacosPlugin.register(with: registry.registrar(forPlugin: "SharePlusMacosPlugin"))
  FVPVideoPlayerPlugin.register(with: registry.registrar(forPlugin: "FVPVideoPlayerPlugin"))
}
