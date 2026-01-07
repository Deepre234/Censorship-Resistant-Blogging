class CensorshipResistantBlog {
    constructor() {
        this.userSession = null;
        this.isConnected = false;
        this.currentUser = null;
        this.contractAddress = 'SP1EXAMPLE123456789ABCDEFGHIJK';
        this.contractName = 'censorship-resistant';
        this.init();
    }

    async init() {
        this.attachEventListeners();
        await this.loadStats();
        await this.loadPosts();
        this.checkWalletConnection();
    }

    attachEventListeners() {
        document.getElementById('connectBtn').addEventListener('click', () => this.connectWallet());
        document.getElementById('registerBtn').addEventListener('click', () => this.openRegisterModal());
        document.getElementById('createPostForm').addEventListener('submit', (e) => this.createPost(e));
        document.getElementById('registerForm').addEventListener('submit', (e) => this.registerUser(e));
        
        document.querySelectorAll('.close').forEach(closeBtn => {
            closeBtn.addEventListener('click', () => this.closeModals());
        });

        window.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModals();
            }
        });
    }

    async connectWallet() {
        try {
            if (typeof window.StacksProvider === 'undefined') {
                alert('Please install Stacks Wallet to continue');
                return;
            }

            const connectBtn = document.getElementById('connectBtn');
            connectBtn.textContent = 'Connecting...';
            connectBtn.disabled = true;

            await window.stacks.connect();
            this.isConnected = true;
            
            const userAddress = await window.stacks.getAddress();
            await this.loadUserProfile(userAddress);
            
            connectBtn.style.display = 'none';
            this.updateUI();
        } catch (error) {
            console.error('Wallet connection failed:', error);
            alert('Failed to connect wallet');
            document.getElementById('connectBtn').disabled = false;
            document.getElementById('connectBtn').textContent = 'Connect Wallet';
        }
    }

    async loadUserProfile(address) {
        try {
            const result = await this.callReadOnlyFunction('get-user-by-address', [address]);
            if (result.success && result.result) {
                this.currentUser = result.result;
                document.getElementById('userInfo').textContent = `Welcome, ${this.currentUser.username}!`;
                document.getElementById('userInfo').style.display = 'block';
                document.getElementById('postForm').style.display = 'block';
                document.getElementById('userCard').style.display = 'block';
                this.updateUserCard();
            } else {
                document.getElementById('registerBtn').style.display = 'block';
            }
        } catch (error) {
            console.error('Failed to load user profile:', error);
            document.getElementById('registerBtn').style.display = 'block';
        }
    }

    updateUserCard() {
        if (!this.currentUser) return;
        
        const userProfile = document.getElementById('userProfile');
        userProfile.innerHTML = `
            <p><strong>${this.currentUser.username}</strong></p>
            <p>${this.currentUser.bio}</p>
            <p>📝 Posts: ${this.currentUser.postCount}</p>
            <p>💰 Tips Received: ${this.currentUser.totalTipsReceived} STX</p>
        `;
    }

    openRegisterModal() {
        document.getElementById('registerModal').style.display = 'block';
    }

    closeModals() {
        document.querySelectorAll('.modal').forEach(modal => {
            modal.style.display = 'none';
        });
    }

    async registerUser(e) {
        e.preventDefault();
        
        if (!this.isConnected) {
            alert('Please connect your wallet first');
            return;
        }

        const username = document.getElementById('username').value;
        const bio = document.getElementById('bio').value;

        try {
            const result = await this.callContractFunction('register-user', [username, bio]);
            if (result.success) {
                alert('Account registered successfully!');
                this.closeModals();
                await this.loadUserProfile(await window.stacks.getAddress());
            } else {
                alert(`Registration failed: ${result.error}`);
            }
        } catch (error) {
            console.error('Registration error:', error);
            alert('Registration failed. Please try again.');
        }
    }

    async createPost(e) {
        e.preventDefault();
        
        if (!this.isConnected || !this.currentUser) {
            alert('Please connect your wallet and register first');
            return;
        }

        const title = document.getElementById('postTitle').value;
        const content = document.getElementById('postContent').value;

        try {
            const result = await this.callContractFunction('create-post', [title, content]);
            if (result.success) {
                alert('Post created successfully!');
                document.getElementById('createPostForm').reset();
                await this.loadPosts();
                await this.loadStats();
            } else {
                alert(`Failed to create post: ${result.error}`);
            }
        } catch (error) {
            console.error('Post creation error:', error);
            alert('Failed to create post. Please try again.');
        }
    }

    async loadStats() {
        try {
            const result = await this.callReadOnlyFunction('get-contract-stats', []);
            if (result.success) {
                document.getElementById('totalUsers').textContent = result.result.totalUsers;
                document.getElementById('totalPosts').textContent = result.result.totalPosts;
                document.getElementById('currentBlock').textContent = result.result.currentBlock;
            }
        } catch (error) {
            console.error('Failed to load stats:', error);
        }
    }

    async loadPosts() {
        try {
            const nextPostId = await this.callReadOnlyFunction('get-next-post-id', []);
            if (!nextPostId.success) return;

            const posts = [];
            for (let i = 1; i < nextPostId.result; i++) {
                const post = await this.callReadOnlyFunction('get-post', [i]);
                if (post.success && post.result && post.result.isActive) {
                    const author = await this.callReadOnlyFunction('get-user', [post.result.authorId]);
                    posts.push({
                        id: i,
                        ...post.result,
                        author: author.success ? author.result : null
                    });
                }
            }

            this.displayPosts(posts.reverse());
        } catch (error) {
            console.error('Failed to load posts:', error);
        }
    }

    displayPosts(posts) {
        const postsGrid = document.getElementById('postsGrid');
        postsGrid.innerHTML = '';

        posts.forEach(post => {
            const postElement = document.createElement('div');
            postElement.className = 'post-card';
            postElement.innerHTML = `
                <div class="post-header">
                    <div class="post-author">${post.author?.username || 'Anonymous'}</div>
                    <div class="post-date">Block ${post.createdAt}</div>
                </div>
                <div class="post-title">${post.title}</div>
                <div class="post-content">${post.content}</div>
                <div class="post-actions">
                    <button class="action-btn" onclick="app.reactToPost(${post.id}, 'like')">
                        👍 ${post.likes}
                    </button>
                    <button class="action-btn" onclick="app.reactToPost(${post.id}, 'dislike')">
                        👎 ${post.dislikes}
                    </button>
                    <button class="action-btn" onclick="app.tipPost(${post.id})">
                        💰 Tip (${post.tipsReceived} STX)
                    </button>
                </div>
            `;
            postsGrid.appendChild(postElement);
        });
    }

    async reactToPost(postId, reaction) {
        if (!this.isConnected) {
            alert('Please connect your wallet first');
            return;
        }

        try {
            const result = await this.callContractFunction('react-to-post', [postId, reaction]);
            if (result.success) {
                await this.loadPosts();
            } else {
                alert(`Failed to react: ${result.error}`);
            }
        } catch (error) {
            console.error('Reaction error:', error);
            alert('Failed to react. Please try again.');
        }
    }

    async tipPost(postId) {
        if (!this.isConnected) {
            alert('Please connect your wallet first');
            return;
        }

        document.getElementById('tipModal').style.display = 'block';
        document.getElementById('sendTipBtn').onclick = async () => {
            const amount = document.getElementById('tipAmount').value;
            if (!amount || amount <= 0) {
                alert('Please enter a valid tip amount');
                return;
            }

            try {
                const result = await this.callContractFunction('tip-post', [postId]);
                if (result.success) {
                    alert('Tip sent successfully!');
                    this.closeModals();
                    await this.loadPosts();
                } else {
                    alert(`Failed to send tip: ${result.error}`);
                }
            } catch (error) {
                console.error('Tip error:', error);
                alert('Failed to send tip. Please try again.');
            }
        };
    }

    async callContractFunction(functionName, args) {
        try {
            const result = await window.stacks.callContract({
                contractAddress: this.contractAddress,
                contractName: this.contractName,
                functionName: functionName,
                functionArgs: args
            });
            return { success: true, result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    async callReadOnlyFunction(functionName, args) {
        try {
            const result = await window.stacks.callReadOnlyFunction({
                contractAddress: this.contractAddress,
                contractName: this.contractName,
                functionName: functionName,
                functionArgs: args
            });
            return { success: true, result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    checkWalletConnection() {
        if (typeof window.stacks !== 'undefined') {
            window.stacks.getUserData().then(userData => {
                if (userData) {
                    this.isConnected = true;
                    this.loadUserProfile(userData.profile.stxAddress.mainnet);
                }
            }).catch(() => {
                console.log('Wallet not connected');
            });
        }
    }

    updateUI() {
        document.getElementById('userInfo').style.display = this.isConnected ? 'block' : 'none';
        document.getElementById('connectBtn').style.display = this.isConnected ? 'none' : 'block';
        document.getElementById('postForm').style.display = this.currentUser ? 'block' : 'none';
        document.getElementById('userCard').style.display = this.currentUser ? 'block' : 'none';
    }
}

const app = new CensorshipResistantBlog();
