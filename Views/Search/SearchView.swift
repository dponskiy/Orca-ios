//
//  SearchView.swift
//  Orca
//
//  Created by David Piliponskiy on 2/25/26.
//

import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Search coming soon")
                    .font(.custom("DMSans-Regular", size: 16))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pearl)
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}
