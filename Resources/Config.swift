//
//  Config.swift
//  Orca
//
//  Created by David Piliponskiy on 2/24/26.
//

import Foundation

enum Config {
    // Supabase
    static let supabaseURL = "https://nxugxxonutrbglldeinc.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im54dWd4eG9udXRyYmdsbGRlaW5jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NzI4NTksImV4cCI6MjA4NzQ0ODg1OX0.yyUjeouMK8j8ONNmc291kIulUcQLEj4__0QvnuscOf8"

    // Mixpanel
    static let mixpanelToken = "47abe570a284d9500c848fce71569951"

    // TMDB
    static let tmdbReadToken = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI2NzgyYjliMTgwMTk4YmQ4ZjZkMDhjYmI4ZmY5MmZmYSIsIm5iZiI6MTc3ODI1MTM4MS41ODMwMDAyLCJzdWIiOiI2OWZkZjY3NTBlMDNjMDFiMjZhYTlhYTIiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.JwMxXNf8B-UC-GioVLnHpZGhQx9Vlx9tylpy5UDcaaE"

    // Rebrickable (free key at rebrickable.com/api/)
    static let rebrickableApiKey = "055d3136d0609c700bfbdc2bba30096b"

    // IGDB (via Twitch — dev.twitch.tv/console/apps)
    static let igdbClientId     = "smxjmt8r5ugkdsoymgmrdm0n4aqnq1"
    static let igdbClientSecret = "0hgnyxxdfgtr7zdjly4qbymp8323sn"

    // App
    static let privacyURL = "https://orcadrop.app/privacy"
    static let termsURL = "https://orcadrop.app/terms"
}
