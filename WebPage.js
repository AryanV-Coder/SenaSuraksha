 // Initialize login time
        document.getElementById('loginTime').textContent = new Date().toLocaleTimeString();

        // Sample soldier data
        const soldiers = [
            { id: 'ALPHA-001', name: 'Pvt. Johnson', health: 95, status: 'operational', lastUpdate: '2 min ago' },
            { id: 'BRAVO-002', name: 'Cpl. Martinez', health: 65, status: 'caution', lastUpdate: '5 min ago' },
            { id: 'CHARLIE-003', name: 'Sgt. Williams', health: 25, status: 'critical', lastUpdate: '1 min ago' },
            { id: 'DELTA-004', name: 'Pvt. Brown', health: 88, status: 'operational', lastUpdate: '3 min ago' },
            { id: 'ECHO-005', name: 'Cpl. Davis', health: 72, status: 'caution', lastUpdate: '4 min ago' },
            { id: 'FOXTROT-006', name: 'Pvt. Wilson', health: 91, status: 'operational', lastUpdate: '6 min ago' },
            { id: 'GOLF-007', name: 'Sgt. Taylor', health: 45, status: 'caution', lastUpdate: '7 min ago' },
            { id: 'HOTEL-008', name: 'Pvt. Anderson', health: 0, status: 'dead', lastUpdate: '15 min ago' }
        ];

        function toggleVoice(element) {
            element.classList.toggle('active');
            if (element.classList.contains('active')) {
                setTimeout(() => element.classList.remove('active'), 3000);
            }
        }

        function showSoldierChart() {
            const modal = document.getElementById('soldierModal');
            const chart = document.getElementById('soldierChart');
            
            chart.innerHTML = '';
            
            soldiers.forEach(soldier => {
                const card = document.createElement('div');
                card.className = 'soldier-card';
                
                const statusIcon = getStatusIcon(soldier.status);
                const healthColor = getHealthColor(soldier.health);
                
                card.innerHTML = `
                    <div class="soldier-card-icon">
                        👤
                        <div class="status-indicator ${statusIcon}"></div>
                    </div>
                    <div class="soldier-details">
                        <div class="soldier-name">${soldier.name}</div>
                        <div class="soldier-id">ID: ${soldier.id}</div>
                        <div class="soldier-status">
                            <span class="status-badge status-${soldier.status}">${soldier.status.toUpperCase()}</span>
                            <small style="margin-left: 10px; color: #666;">Last update: ${soldier.lastUpdate}</small>
                        </div>
                    </div>
                    <div style="text-align: center;">
                        <div><strong>Health: ${soldier.health}%</strong></div>
                        <div class="soldier-health-bar">
                            <div class="soldier-health-fill" style="width: ${soldier.health}%; background-color: ${healthColor};"></div>
                        </div>
                    </div>
                `;
                
                chart.appendChild(card);
            });
            
            modal.style.display = 'block';
        }

        function closeSoldierModal() {
            document.getElementById('soldierModal').style.display = 'none';
        }

        function getStatusIcon(status) {
            const icons = {
                'operational': 'status-green',
                'caution': 'status-yellow',
                'critical': 'status-red',
                'dead': 'status-gray'
            };
            return icons[status] || 'status-gray';
        }

        function getHealthColor(health) {
            if (health >= 80) return '#90EE90';
            if (health >= 50) return '#FFD700';
            if (health > 0) return '#FF6B6B';
            return '#999999';
        }

        function activateEmergency() {
            const button = document.querySelector('.emergency-button');
            button.classList.add('active');
            alert('🚨 EMERGENCY ALERT ACTIVATED! 🚨\nBroadcasting emergency signal to all units...');
            setTimeout(() => button.classList.remove('active'), 3000);
        }

        function openChatBot() {
            alert('💬 ChatBot Activated!\nHello Commander! How can I assist you today?\n\n• Check soldier status\n• Generate reports\n• Emergency protocols\n• Mission briefings');
        }

        function logout() {
            if (confirm('Are you sure you want to log out?')) {
                alert('Logging out... Session ended.');
                document.getElementById('logoutTime').textContent = new Date().toLocaleTimeString();
            }
        }

        function showPathPredictor() {
            alert('📍 Path Predictor Active!\nAnalyzing soldier movement patterns and predicting optimal routes based on:\n• Terrain data\n• Threat assessment\n• Mission objectives');
        }

        function highlightSymbol(type) {
            alert(`Selected: ${type.charAt(0).toUpperCase() + type.slice(1)} soldier markers\nClick on map to filter by this status.`);
        }

        function adjustHealth(healthBarElement, soldierId) {
            const currentHealth = parseInt(healthBarElement.getAttribute('data-health'));
            
            // Create a simple prompt for health adjustment
            const newHealth = prompt(`Adjust health for ${soldierId}\nCurrent: ${currentHealth}%\nEnter new health percentage (0-100):`, currentHealth);
            
            if (newHealth !== null && !isNaN(newHealth)) {
                const healthValue = Math.max(0, Math.min(100, parseInt(newHealth)));
                updateSoldierHealth(healthBarElement, healthValue, soldierId);
            }
        }

        function updateSoldierHealth(healthBarElement, newHealth, soldierId) {
            // Update the health bar
            healthBarElement.setAttribute('data-health', newHealth);
            const healthFill = healthBarElement.querySelector('.health-fill');
            const healthPercentage = healthBarElement.querySelector('.health-percentage');
            
            healthFill.style.width = newHealth + '%';
            healthPercentage.textContent = newHealth + '%';
            
            // Update health bar color and class
            healthFill.className = 'health-fill';
            if (newHealth >= 70) {
                healthFill.classList.add('high');
            } else if (newHealth >= 40) {
                healthFill.classList.add('medium');
            } else {
                healthFill.classList.add('low');
            }
            
            // Update status indicator
            const statusIndicator = healthBarElement.parentElement.querySelector('.status-indicator');
            if (newHealth >= 70) {
                statusIndicator.className = 'status-indicator status-green';
            } else if (newHealth >= 40) {
                statusIndicator.className = 'status-indicator status-yellow';
            } else {
                statusIndicator.className = 'status-indicator status-red';
            }
            
            // Update soldier data in the array
            const soldier = soldiers.find(s => s.id.includes(soldierId.split('-')[0].toUpperCase()));
            if (soldier) {
                soldier.health = newHealth;
                soldier.lastUpdate = 'Just now';
                
                // Update status based on health
                if (newHealth >= 70) {
                    soldier.status = 'operational';
                } else if (newHealth >= 40) {
                    soldier.status = 'caution';
                } else if (newHealth > 0) {
                    soldier.status = 'critical';
                } else {
                    soldier.status = 'dead';
                }
            }
            
            // Show confirmation
            showHealthUpdateNotification(soldierId, newHealth);
        }

        function showHealthUpdateNotification(soldierId, health) {
            // Create a temporary notification
            const notification = document.createElement('div');
            notification.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                background: #4CAF50;
                color: white;
                padding: 15px 20px;
                border-radius: 5px;
                font-weight: bold;
                z-index: 1001;
                box-shadow: 0 4px 8px rgba(0,0,0,0.2);
                animation: slideIn 0.3s ease;
            `;
            
            let statusText = 'OPERATIONAL';
            let bgColor = '#4CAF50';
            
            if (health < 70 && health >= 40) {
                statusText = 'CAUTION';
                bgColor = '#FF9800';
            } else if (health < 40 && health > 0) {
                statusText = 'CRITICAL';
                bgColor = '#F44336';
            } else if (health === 0) {
                statusText = 'DEAD';
                bgColor = '#9E9E9E';
            }
            
            notification.style.backgroundColor = bgColor;
            notification.innerHTML = `✅ ${soldierId} Health Updated<br>New Status: ${health}% - ${statusText}`;
            
            document.body.appendChild(notification);
            
            // Remove notification after 3 seconds
            setTimeout(() => {
                notification.remove();
            }, 3000);
        }

        // Close modal when clicking outside
        window.onclick = function(event) {
            const modal = document.getElementById('soldierModal');
            if (event.target === modal) {
                modal.style.display = 'none';
            }
        }
        // Soldier Management Functions
        function viewSoldierInfo() {
            // This will show the same modal as the "View More" button
            showSoldierChart();
            
            // Show a specific notification
            showManagementNotification('Viewing all soldier information', '#4CAF50');
        }
        
        function addSoldierInfo() {
            // Prompt for new soldier details
            const soldierName = prompt('Enter new soldier name (e.g., Pvt. Smith):');
            if (!soldierName) return;
            
            const soldierId = prompt('Enter new soldier ID (e.g., INDIA-009):');
            if (!soldierId) return;
            
            let soldierHealth = parseInt(prompt('Enter initial health percentage (0-100):', '100'));
            if (isNaN(soldierHealth)) soldierHealth = 100;
            soldierHealth = Math.max(0, Math.min(100, soldierHealth));
            
            // Determine status based on health
            let status;
            if (soldierHealth >= 70) {
                status = 'operational';
            } else if (soldierHealth >= 40) {
                status = 'caution';
            } else if (soldierHealth > 0) {
                status = 'critical';
            } else {
                status = 'dead';
            }
            
            // Create new soldier object
            const newSoldier = {
                id: soldierId.toUpperCase(),
                name: soldierName,
                health: soldierHealth,
                status: status,
                lastUpdate: 'Just added'
            };
            
            // Add to soldiers array
            soldiers.push(newSoldier);
            
            // Update the UI
            updateSoldierHealthUI(newSoldier);
            
            // Show confirmation
            showManagementNotification(`Added new soldier: ${soldierName} (${soldierId})`, '#2196F3');
        }
        
        function deleteSoldierInfo() {
            // Create a list of soldier names for selection
            const soldierList = soldiers.map(s => `${s.name} (${s.id})`).join('\n');
            
            const soldierToDelete = prompt(`Enter soldier ID to delete:\n\nCurrent soldiers:\n${soldierList}`);
            if (!soldierToDelete) return;
            
            // Find the soldier index
            const index = soldiers.findIndex(s => 
                s.id.toLowerCase() === soldierToDelete.toLowerCase() || 
                s.name.toLowerCase().includes(soldierToDelete.toLowerCase())
            );
            
            if (index === -1) {
                alert('Soldier not found!');
                return;
            }
            
            // Confirm deletion
            if (confirm(`Are you sure you want to delete ${soldiers[index].name} (${soldiers[index].id})?`)) {
                const deletedSoldier = soldiers.splice(index, 1)[0];
                showManagementNotification(`Deleted soldier: ${deletedSoldier.name} (${deletedSoldier.id})`, '#f44336');
            }
        }
        
        function updateSoldierHealthUI(soldier) {
            // This would update the main health bars if we were showing all soldiers
            // In a full implementation, we'd need to regenerate the health bars section
            // For now, we'll just update the modal if it's open
            if (document.getElementById('soldierModal').style.display === 'block') {
                showSoldierChart();
            }
        }
        
        function showManagementNotification(message, color) {
            // Create a temporary notification
            const notification = document.createElement('div');
            notification.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                background: ${color};
                color: white;
                padding: 15px 20px;
                border-radius: 5px;
                font-weight: bold;
                z-index: 1001;
                box-shadow: 0 4px 8px rgba(0,0,0,0.2);
                animation: slideIn 0.3s ease;
            `;
            
            notification.innerHTML = message;
            
            document.body.appendChild(notification);
            
            // Remove notification after 3 seconds
            setTimeout(() => {
                notification.remove();
            }, 3000);
        }
