import Foundation
import CloudKit

struct BudgetCloudSnapshot: Codable {
    var schemaVersion = 1
    var updatedAt: Date
    var categories: [BudgetCategory]
    var transactions: [Transaction]
    var spendLists: [SpendList]

    var hasUserData: Bool {
        !spendLists.isEmpty || !transactions.isEmpty || categories != BudgetCategory.sample
    }
}

final class ICloudSyncStore {
    enum AccountState {
        case available
        case unavailable(String)
    }

    private let database = CKContainer.default().privateCloudDatabase
    private let container = CKContainer.default()
    private let recordType = "BudgetSnapshot"
    private let recordID = CKRecord.ID(recordName: "primaryBudgetSnapshot")
    private let payloadKey = "payload"
    private let updatedAtKey = "updatedAt"

    func accountState(completion: @escaping (AccountState) -> Void) {
        container.accountStatus { status, error in
            let state: AccountState
            if let error {
                state = .unavailable(error.localizedDescription)
            } else {
                switch status {
                case .available:
                    state = .available
                case .noAccount:
                    state = .unavailable("No iCloud account is signed in.")
                case .restricted:
                    state = .unavailable("iCloud is restricted on this device.")
                case .couldNotDetermine:
                    state = .unavailable("Could not determine iCloud account status.")
                case .temporarilyUnavailable:
                    state = .unavailable("iCloud is temporarily unavailable.")
                @unknown default:
                    state = .unavailable("Unknown iCloud account status.")
                }
            }

            DispatchQueue.main.async {
                completion(state)
            }
        }
    }

    func loadSnapshot(completion: @escaping (Result<BudgetCloudSnapshot?, Error>) -> Void) {
        database.fetch(withRecordID: recordID) { [payloadKey] record, error in
            if let cloudError = error as? CKError, cloudError.code == .unknownItem {
                DispatchQueue.main.async {
                    completion(.success(nil))
                }
                return
            }

            guard
                let error = error
            else {
                guard
                    let data = record?[payloadKey] as? Data,
                    let snapshot = try? JSONDecoder().decode(BudgetCloudSnapshot.self, from: data)
                else {
                    DispatchQueue.main.async {
                        completion(.success(nil))
                    }
                    return
                }

                DispatchQueue.main.async {
                    completion(.success(snapshot))
                }
                return
            }

            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }

    func save(_ snapshot: BudgetCloudSnapshot, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            completion?(.failure(CocoaError(.fileWriteUnknown)))
            return
        }

        database.fetch(withRecordID: recordID) { [database, recordType, recordID, payloadKey, updatedAtKey] record, error in
            let snapshotRecord: CKRecord
            if let record {
                snapshotRecord = record
            } else if let cloudError = error as? CKError, cloudError.code == .unknownItem {
                snapshotRecord = CKRecord(recordType: recordType, recordID: recordID)
            } else if let error {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
                return
            } else {
                snapshotRecord = CKRecord(recordType: recordType, recordID: recordID)
            }

            snapshotRecord[payloadKey] = data as NSData
            snapshotRecord[updatedAtKey] = snapshot.updatedAt as NSDate
            database.save(snapshotRecord) { _, error in
                DispatchQueue.main.async {
                    if let error {
                        completion?(.failure(error))
                    } else {
                        completion?(.success(()))
                    }
                }
            }
        }
    }
}
