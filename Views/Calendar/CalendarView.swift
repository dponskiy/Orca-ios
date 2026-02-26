//
//  CalendarView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

struct CalendarTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Calendar coming soon")
                    .font(.custom("DMSans-Regular", size: 16))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pearl)
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    CalendarTabView()
}
