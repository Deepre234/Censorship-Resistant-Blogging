# 📝 Censorship-Resistant Blogging Platform

> 🚀 A decentralized blogging platform built on Stacks blockchain where freedom of speech meets financial incentives

## 🌟 Features

- 📚 **Immutable Posts**: All blog posts are stored permanently on the Stacks blockchain
- 💰 **STX Tipping**: Replace traditional ads with direct creator support through STX tips
- 👥 **User Profiles**: Create and manage your on-chain identity
- 💖 **Social Interactions**: Like, dislike, and engage with content
- 🔐 **Censorship Resistance**: No central authority can remove or modify posts
- 📱 **Responsive Design**: Works seamlessly on desktop and mobile devices

## 🛠️ Smart Contract Functions

### Public Functions
- `register-user(username, bio)` - Register a new user account
- `create-post(title, content)` - Publish a new blog post
- `tip-post(post-id)` - Send STX tips to post authors
- `react-to-post(post-id, reaction)` - Like or dislike posts
- `follow-user(user-id)` - Follow another user
- `unfollow-user(user-id)` - Unfollow a user
- `deactivate-post(post-id)` - Deactivate your own post

### Read-Only Functions
- `get-user(user-id)` - Get user profile information
- `get-post(post-id)` - Get post details
- `get-contract-stats()` - Get platform statistics
- `is-following(follower-id, following-id)` - Check follow status

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks Wallet](https://www.hiro.so/wallet) browser extension
- Node.js and npm (for local development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/censorship-resistant-blogging.git
   cd censorship-resistant-blogging
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Test the contract**
   ```bash
   clarinet test
   ```

4. **Deploy to testnet**
   ```bash
   clarinet deploy --testnet
   ```

5. **Run the UI locally**
   ```bash
   # Serve the HTML files using any static server
   python -m http.server 8000
   # or
   npx serve .
   ```

## 🎯 Usage

### For Users
1. **Connect Wallet**: Click "Connect Wallet" and approve the connection
2. **Register**: Create your on-chain profile with username and bio
3. **Write Posts**: Share your thoughts in up to 2000 characters
4. **Tip Creators**: Support authors with STX tips
5. **Engage**: Like, dislike, and follow other users

### For Developers
1. **Contract Integration**: Use the provided JavaScript class to interact with the contract
2. **Customize UI**: Modify the responsive CSS for your brand
3. **Extend Features**: Add new functions to the smart contract
4. **Test**: Run comprehensive tests with Clarinet

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend UI   │    │  Stacks Chain   │    │ Smart Contract  │
│   (HTML/CSS/JS) │───▶│   (Storage)     │◀───│  (Clarity)      │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Stacks Wallet  │    │   User Data     │    │   Post Data     │
│  (Authentication)│    │   (Profiles)    │    │   (Content)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📊 Data Models

### User
- `user-id`: Unique identifier
- `address`: Stacks address
- `username`: Display name (max 50 chars)
- `bio`: User description (max 500 chars)
- `post-count`: Number of posts created
- `total-tips-received`: Total STX earned
- `joined-at`: Registration block height

### Post
- `post-id`: Unique identifier
- `author-id`: Creator's user ID
- `title`: Post title (max 100 chars)
- `content`: Post content (max 2000 chars)
- `created-at`: Creation block height
- `tips-received`: Total STX tips
- `likes`: Number of likes
- `dislikes`: Number of dislikes
- `is-active`: Active status

## 🔐 Security Features

- ✅ **Immutable Storage**: Posts cannot be altered once published
- ✅ **Ownership Verification**: Only post authors can deactivate their content
- ✅ **Input Validation**: All user inputs are validated and sanitized
- ✅ **Error Handling**: Comprehensive error codes and messages
- ✅ **Access Control**: Function-level permissions and authorization

## 🌐 Browser Support

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+
- ✅ Mobile browsers (iOS Safari, Chrome Mobile)

## 📱 Accessibility

- ✅ WCAG 2.1 AA compliant
- ✅ Keyboard navigation support
- ✅ Screen reader compatible
- ✅ High contrast mode
- ✅ Responsive design for all screen sizes

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Stacks](https://stacks.co/) for the blockchain infrastructure
- [Clarinet](https://github.com/hirosystems/clarinet) for development tools
- [Clarity](https://clarity-lang.org/) for the smart contract language

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Reference](https://docs.stacks.co/clarity/)
- [Clarinet Guide](https://docs.stacks.co/clarinet/)

---

**Built with ❤️ for a decentralized future**
