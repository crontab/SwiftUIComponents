//
//  Database.swift
//
//  Created by Hovik Melikyan on 24.04.25.
//

import Foundation
import SwiftData


protocol Database<T> {
	associatedtype T = PersistentModel
	var container: ModelContainer { get }
	func create(_ item: T) throws
	func create(_ items: [T]) throws
	func read(_ predicate: Predicate<T>?, sort: SortDescriptor<T>...) throws -> [T]
	func update(_ item: T) throws
	func delete(_ item: T) throws
}


extension Database {

	func create<T: PersistentModel>(_ item: T) throws {
		let context = ModelContext(container)
		context.insert(item) // this is actually upsert
		try context.save()
	}

	func create<T: PersistentModel>(_ items: [T]) throws {
		let context = ModelContext(container)
		for item in items {
			context.insert(item)
		}
		try context.save()
	}

	func read<T: PersistentModel>(_ predicate: Predicate<T>?, sort: SortDescriptor<T>...) throws -> [T] {
		let context = ModelContext(container)
		return try context.fetch(FetchDescriptor<T>(predicate: predicate, sortBy: sort))
	}

	func update<T: PersistentModel>(_ item: T) throws {
		try create(item)
	}

	func delete<T: PersistentModel>(_ item: T) throws {
		let context = ModelContext(container)
		context.delete(item)
		try context.save()
	}
}


// MARK: - Volume progress

@Model
final class VolumeProgress {

	@Model
	final class EpisodeProgress {
		var id: String
		var progress: Double

		init(id: String, progress: Double) {
			self.id = id
			self.progress = progress
		}
	}

	@Attribute(.unique) var id: String
	var episodes: [EpisodeProgress]
	var isDirty: Bool

	init(id: String, episodes: [EpisodeProgress], isDirty: Bool) {
		self.id = id
		self.episodes = episodes
		self.isDirty = isDirty
	}
}


final class ProgressDatabase: Database {
	typealias T = VolumeProgress

	let container: ModelContainer

	init() throws {
		self.container = try .init(for: T.self)
	}
}


// MARK: - Reader updates


@Model
final class ReaderUpdate {
	enum Action: String {
		case start, `continue`, end
	}

	var sessionId: String
	var volumeId: String
	var episodeId: String
	var language: String
	var timestamp: Int
	var action: String
	var progress: Double

	init(sessionId: String, volumeId: String, episodeId: String, language: String, timestamp: Int, action: Action, progress: Double) {
		self.sessionId = sessionId
		self.volumeId = volumeId
		self.episodeId = episodeId
		self.language = language
		self.timestamp = timestamp
		self.action = action.rawValue
		self.progress = progress
	}
}


@globalActor
actor ReaderUpdates {

	static let shared = ReaderUpdates()

	private init() {
		self.db = try! .init()
	}

	private let db: ReaderDatabase

	private final class ReaderDatabase: Database {
		typealias T = ReaderUpdate

		let container: ModelContainer

		init() throws {
			self.container = try .init(for: T.self)
		}
	}
}
