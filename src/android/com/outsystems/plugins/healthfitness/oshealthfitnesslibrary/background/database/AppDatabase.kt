package com.outsystems.plugins.healthfitnesslib.background.database

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.room.migration.Migration

@Database(
    entities = [BackgroundJob::class, Notification::class],
    version = 2
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun backgroundJobDao(): BackgroundJobDao
    abstract fun notificationDao(): NotificationDao

    companion object {
        val MIGRATION_1_2: Migration = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL(
                    "ALTER TABLE ${BackgroundJob.TABLE_NAME} " +
                            "ADD COLUMN notification_frequency TEXT NOT NULL DEFAULT 'ALWAYS'")
                database.execSQL(
                    "ALTER TABLE ${BackgroundJob.TABLE_NAME} " +
                            "ADD COLUMN notification_frequency_grouping INTEGER NOT NULL DEFAULT 1")
                database.execSQL(
                    "ALTER TABLE ${BackgroundJob.TABLE_NAME} " +
                            "ADD COLUMN next_notification_timestamp INTEGER NOT NULL DEFAULT 0")
                database.execSQL(
                    "ALTER TABLE ${BackgroundJob.TABLE_NAME} " +
                            "ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1")
            }
        }
    }
}