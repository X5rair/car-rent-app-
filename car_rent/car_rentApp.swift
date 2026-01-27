//
//  car_rentApp.swift
//  car_rent
//
//  Created by rair on 21.01.2026.
//

import SwiftUI
import FirebaseCore

@main
struct car_rentApp: App {

    init() {
        // Инициализируем Firebase при старте приложения
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
