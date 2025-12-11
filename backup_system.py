"""
Sistema de Backup y Restauración - Trading Bot
Protege tu configuración antes de aplicar mejoras
"""

import json
import os
import shutil
from datetime import datetime
import hashlib

class BackupSystem:
    def __init__(self):
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.backup_dir = os.path.join(self.base_dir, 'BACKUPS')
        self.critical_files = [
            'config.json',
            'signal_generator.py',
            'main.py',
            'account_risk_manager.py',
            'position_sizer.py',
            'web_interface.py',
        ]
        
        if not os.path.exists(self.backup_dir):
            os.makedirs(self.backup_dir)

    def create_backup(self, backup_name=None):
        if backup_name is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_name = f"backup_{timestamp}"
        
        backup_path = os.path.join(self.backup_dir, backup_name)
        
        if os.path.exists(backup_path):
            print(f"[WARNING] Backup already exists: {backup_name}")
            return backup_path
        
        os.makedirs(backup_path)
        
        metadata = {
            'timestamp': datetime.now().isoformat(),
            'backup_name': backup_name,
            'files_backed_up': [],
            'file_hashes': {},
            'total_size_bytes': 0
        }
        
        print(f"\n[BACKUP] Creating backup: {backup_name}")
        print("=" * 70)
        
        for filename in self.critical_files:
            source_path = os.path.join(self.base_dir, filename)
            
            if not os.path.exists(source_path):
                print(f"[SKIP] File not found: {filename}")
                continue
            
            dest_path = os.path.join(backup_path, filename)
            
            if os.path.isfile(source_path):
                shutil.copy2(source_path, dest_path)
                file_size = os.path.getsize(dest_path)
                file_hash = self._calc_hash(dest_path)
                
                metadata['files_backed_up'].append(filename)
                metadata['file_hashes'][filename] = file_hash
                metadata['total_size_bytes'] += file_size
                
                print(f"[OK] {filename:30s} ({file_size:>10,} bytes)")
        
        metadata_path = os.path.join(backup_path, 'METADATA.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print("=" * 70)
        print(f"[COMPLETE] Backup finished")
        print(f"  Location: {backup_path}")
        print(f"  Files: {len(metadata['files_backed_up'])}")
        print(f"  Size: {metadata['total_size_bytes'] / 1024 / 1024:.2f} MB")
        
        return backup_path

    def list_backups(self):
        backups = []
        
        if not os.path.exists(self.backup_dir):
            return backups
        
        for backup_name in sorted(os.listdir(self.backup_dir)):
            backup_path = os.path.join(self.backup_dir, backup_name)
            metadata_path = os.path.join(backup_path, 'METADATA.json')
            
            if os.path.isfile(metadata_path):
                with open(metadata_path, 'r') as f:
                    metadata = json.load(f)
                    backups.append({
                        'name': backup_name,
                        'path': backup_path,
                        'timestamp': metadata.get('timestamp'),
                        'files': len(metadata.get('files_backed_up', [])),
                        'size_mb': metadata.get('total_size_bytes', 0) / 1024 / 1024
                    })
        
        return backups

    def restore_backup(self, backup_name):
        backup_path = os.path.join(self.backup_dir, backup_name)
        
        if not os.path.exists(backup_path):
            print(f"[ERROR] Backup not found: {backup_name}")
            return False
        
        metadata_path = os.path.join(backup_path, 'METADATA.json')
        if not os.path.isfile(metadata_path):
            print(f"[ERROR] Metadata not found in backup: {backup_name}")
            return False
        
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        
        print(f"\n[RESTORE] Restoring backup: {backup_name}")
        print("=" * 70)
        print(f"Timestamp: {metadata['timestamp']}")
        print(f"Files to restore: {len(metadata['files_backed_up'])}")
        
        print("\n[RESTORING]...")
        print("=" * 70)
        
        for filename in metadata['files_backed_up']:
            source_path = os.path.join(backup_path, filename)
            dest_path = os.path.join(self.base_dir, filename)
            
            try:
                if os.path.isfile(source_path):
                    if os.path.exists(dest_path):
                        temp_backup = dest_path + '.pre_restore'
                        shutil.copy2(dest_path, temp_backup)
                    
                    shutil.copy2(source_path, dest_path)
                    print(f"[OK] {filename:30s}")
            
            except Exception as e:
                print(f"[ERROR] {filename:30s} - {str(e)}")
                return False
        
        print("=" * 70)
        print(f"[SUCCESS] Backup restored successfully")
        return True

    def _calc_hash(self, file_path):
        hasher = hashlib.sha256()
        with open(file_path, 'rb') as f:
            while True:
                chunk = f.read(8192)
                if not chunk:
                    break
                hasher.update(chunk)
        return hasher.hexdigest()


if __name__ == "__main__":
    system = BackupSystem()
    print("\n" + "=" * 80)
    print("[BACKUP SYSTEM] Creating initial backup for safety")
    print("=" * 80)
    system.create_backup("BACKUP_INICIAL_ANTES_DE_MEJORAS")
    print("\n[SUCCESS] Initial backup created. Safe to apply improvements.\n")
