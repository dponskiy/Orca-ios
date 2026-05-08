//
//  WeatherDetailView.swift
//  Orca
//

import SwiftUI
import WeatherKit

struct WeatherDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weatherService = WeatherService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pearl.ignoresSafeArea()
                VStack(spacing: 16) {

                    // Weather card
                    VStack(spacing: 8) {
                        Image(systemName: weatherService.symbolName)
                            .font(.system(size: 64))
                            .foregroundColor(.oceanTeal)
                            .padding(.top, 32)

                        Text(weatherService.temperature)
                            .font(.custom("InstrumentSerif-Regular", size: 72))
                            .foregroundColor(.deepNavy)

                        Text(weatherService.currentWeather?.condition.description ?? "")
                            .font(.custom("DMSans-Regular", size: 18))
                            .foregroundColor(.gray)

                        // Attribution right below condition
                        Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                            VStack(spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 12))
                                    Text("Weather")
                                        .font(.custom("DMSans-Medium", size: 13))
                                }
                                Text("weatherkit.apple.com/legal-attribution.html")
                                    .font(.custom("DMMono-Regular", size: 10))
                                    .underline()
                            }
                            .foregroundColor(.gray)
                        }
                        .padding(.bottom, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.06), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Weather")
                        .font(.custom("DMSans-Medium", size: 17))
                        .foregroundColor(.deepNavy)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.oceanTeal)
                }
            }
        }
    }
}
