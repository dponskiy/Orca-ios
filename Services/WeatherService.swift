//
//  WeatherService.swift
//  Orca
//
//  Created by David Piliponskiy on 3/16/26.
//

import Foundation
import WeatherKit
import CoreLocation
import Combine

@MainActor
class WeatherService: ObservableObject {
    static let shared = WeatherService()
    
    @Published var currentWeather: CurrentWeather?
    @Published var temperature: String = ""
    @Published var symbolName: String = "cloud"
    @Published var isLoading = false
    
    private let service = WeatherKit.WeatherService.shared
    private var lastFetchTime: Date?
    private var lastLocation: CLLocation?
    
    private init() {}
    
    func fetchWeather(for location: CLLocation) async {
        // Cache — don't refetch if same location within 30 minutes
        if let lastFetch = lastFetchTime,
           let lastLoc = lastLocation,
           Date().timeIntervalSince(lastFetch) < 1800,
           lastLoc.distance(from: location) < 1000 {
            return
        }
        
        isLoading = true
        do {
            let weather = try await service.weather(for: location)
            currentWeather = weather.currentWeather
            temperature = formatTemperature(weather.currentWeather.temperature)
            symbolName = weather.currentWeather.symbolName
            lastFetchTime = Date()
            lastLocation = location
        } catch {
            print("❌ WeatherKit error: \(error)")
        }
        isLoading = false
    }
    
    private func formatTemperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.unitOptions = .providedUnit
        // Use Fahrenheit for US, Celsius elsewhere
        let locale = Locale.current
        let usesMetric = locale.measurementSystem == .metric
        let converted = usesMetric ?
            measurement.converted(to: .celsius) :
            measurement.converted(to: .fahrenheit)
        return formatter.string(from: converted)
    }
}
