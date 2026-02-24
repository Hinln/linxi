export class RandomProfileUtil {
  private static readonly NICKNAMES = [
    '深海的寄居蟹',
    '云端的极光',
    '森林的守望者',
    '荒野的流浪者',
    '星空的探索者',
    '晨曦的微光',
    '午夜的低语',
    '风中的蒲公英',
    '雨后的彩虹',
    '雪山的孤狼',
  ];

  private static readonly AVATARS = [
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Felix',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Aneka',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Zack',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Molly',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Jasper',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Luna',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Oliver',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Bella',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Leo',
    'https://api.dicebear.com/7.x/adventurer/svg?seed=Milo',
  ];

  static getRandomNickname(): string {
    const index = Math.floor(Math.random() * this.NICKNAMES.length);
    const suffix = Math.floor(1000 + Math.random() * 9000); // Add random 4 digits to avoid collision
    return `${this.NICKNAMES[index]}_${suffix}`;
  }

  static getRandomAvatar(): string {
    const index = Math.floor(Math.random() * this.AVATARS.length);
    return this.AVATARS[index];
  }
}
